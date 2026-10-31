terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

variable "project_name" { type = string }
variable "aws_region" { type = string }
variable "image_uri" { type = string }
variable "database_endpoint" { type = string }
variable "database_port" { type = number }
variable "database_name" { type = string }
variable "database_user" { type = string }
variable "database_password" {
  type      = string
  sensitive = true
}
variable "subnet_ids" { type = list(string) }
variable "security_group_id" { type = string }
variable "email_from" { type = string }
variable "email_to" { type = string }

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

locals {
  bucket_name  = "${var.project_name}-reports-${data.aws_caller_identity.current.account_id}"
  database_url = "postgresql+asyncpg://${var.database_user}:${var.database_password}@${var.database_endpoint}:${var.database_port}/${var.database_name}"
}

resource "aws_s3_bucket" "reports" {
  bucket = local.bucket_name
  lifecycle { prevent_destroy = true }
}

resource "aws_s3_bucket_public_access_block" "reports" {
  bucket                  = aws_s3_bucket.reports.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "reports" {
  bucket = aws_s3_bucket.reports.id
  rule {
    id     = "ExpireReportsAfter90Days"
    status = "Enabled"
    filter { prefix = "reports/" }
    expiration { days = 90 }
  }
}

resource "aws_sqs_queue" "reports_dlq" {
  name                      = "${var.project_name}-report-requests-dlq"
  message_retention_seconds = 1209600
  max_message_size          = 1048576
}

resource "aws_sqs_queue" "reports" {
  name                       = "${var.project_name}-report-requests"
  visibility_timeout_seconds = 360
  max_message_size           = 1048576
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.reports_dlq.arn
    maxReceiveCount     = 3
  })
}

resource "aws_cloudwatch_log_group" "builder" {
  name              = "/aws/lambda/${var.project_name}-report-builder"
  retention_in_days = 14
}

resource "aws_cloudwatch_log_group" "mailer" {
  name              = "/aws/lambda/${var.project_name}-report-mailer"
  retention_in_days = 14
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "builder" {
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  managed_policy_arns = ["arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"]

  inline_policy {
    name = "BuildReports"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["s3:PutObject"]
          Resource = "arn:${data.aws_partition.current.partition}:s3:::${local.bucket_name}/reports/*"
        },
        {
          Effect   = "Allow"
          Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ChangeMessageVisibility"]
          Resource = aws_sqs_queue.reports.arn
        }
      ]
    })
  }
}

resource "aws_iam_role" "mailer" {
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  inline_policy {
    name = "ReadReportsAndSendEmail"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect   = "Allow"
          Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
          Resource = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-report-mailer:*"
        },
        {
          Effect   = "Allow"
          Action   = ["s3:GetObject"]
          Resource = "arn:${data.aws_partition.current.partition}:s3:::${local.bucket_name}/reports/*"
        },
        {
          Effect   = "Allow"
          Action   = ["ses:SendEmail", "ses:SendRawEmail"]
          Resource = "*"
        }
      ]
    })
  }
}

resource "aws_lambda_function" "builder" {
  function_name = "${var.project_name}-report-builder"
  package_type  = "Image"
  image_uri     = var.image_uri
  architectures = ["arm64"]
  memory_size   = 512
  timeout       = 60
  role          = aws_iam_role.builder.arn
  publish       = false

  image_config {
    entry_point = ["python", "-m", "awslambdaric"]
    command     = ["app.reports.lambda_handler.handler"]
  }
  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }
  logging_config {
    log_group  = aws_cloudwatch_log_group.builder.name
    log_format = "Text"
  }
  environment {
    variables = {
      DATABASE_URL    = local.database_url
      DB_POOL_SIZE    = "1"
      DB_MAX_OVERFLOW = "0"
      REPORTS_BUCKET  = aws_s3_bucket.reports.id
    }
  }

  # Do not re-send the sensitive database URL as part of an import-only run. Remove this
  # temporary ignore after the builder has been imported into state.
  lifecycle {
    ignore_changes = [environment[0].variables["DATABASE_URL"]]
  }
}

resource "aws_lambda_function" "mailer" {
  function_name = "${var.project_name}-report-mailer"
  package_type  = "Image"
  image_uri     = var.image_uri
  architectures = ["arm64"]
  memory_size   = 256
  timeout       = 30
  role          = aws_iam_role.mailer.arn
  publish       = false

  image_config {
    entry_point = ["python", "-m", "awslambdaric"]
    command     = ["app.reports.mailer.handler"]
  }
  logging_config {
    log_group  = aws_cloudwatch_log_group.mailer.name
    log_format = "Text"
  }
  environment {
    variables = {
      REPORTS_EMAIL_FROM = var.email_from
      REPORTS_EMAIL_TO   = var.email_to
    }
  }
}

resource "aws_lambda_event_source_mapping" "queue_builder" {
  event_source_arn = aws_sqs_queue.reports.arn
  function_name    = aws_lambda_function.builder.arn
  batch_size       = 1
  enabled          = true
}

data "aws_iam_policy_document" "scheduler_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume_role.json
  inline_policy {
    name = "EnqueueWeeklyReport"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["sqs:SendMessage"]
        Resource = aws_sqs_queue.reports.arn
      }]
    })
  }
}

resource "aws_scheduler_schedule" "weekly" {
  name                         = "${var.project_name}-weekly-report"
  description                  = "Queue the previous ISO week's meetings report every Monday at 07:00 Kyiv time."
  schedule_expression          = "cron(0 7 ? * MON *)"
  schedule_expression_timezone = "Europe/Kyiv"
  state                        = "ENABLED"

  flexible_time_window { mode = "OFF" }
  target {
    arn      = aws_sqs_queue.reports.arn
    role_arn = aws_iam_role.scheduler.arn
    input    = "{\"week\":null,\"source\":\"schedule\"}"
  }
}

resource "aws_lambda_permission" "bucket_invoke_mailer" {
  statement_id   = "new-project-reports-MailerInvokePermission-G2CCVhIg9jBW"
  action         = "lambda:InvokeFunction"
  function_name  = aws_lambda_function.mailer.function_name
  principal      = "s3.amazonaws.com"
  source_arn     = aws_s3_bucket.reports.arn
  source_account = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket_notification" "reports" {
  bucket = aws_s3_bucket.reports.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.mailer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "reports/"
    filter_suffix       = ".csv"
  }
  depends_on = [aws_lambda_permission.bucket_invoke_mailer]
}

output "bucket_name" { value = aws_s3_bucket.reports.bucket }
output "queue_url" { value = aws_sqs_queue.reports.url }
output "dlq_url" { value = aws_sqs_queue.reports_dlq.url }
output "builder_log_group" { value = aws_cloudwatch_log_group.builder.name }
output "mailer_log_group" { value = aws_cloudwatch_log_group.mailer.name }
