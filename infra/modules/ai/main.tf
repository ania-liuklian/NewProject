terraform {
  required_providers {
    aws = { source = "hashicorp/aws" }
  }
}

variable "project_name" { type = string }
variable "aws_region" { type = string }
variable "image_uri" { type = string }
variable "cognito_user_pool_id" { type = string }
variable "cognito_client_id" { type = string }
variable "cors_origins" { type = list(string) }
variable "parser_model" { type = string }
variable "cloudflare_account_id" {
  type      = string
  sensitive = true
}
variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}
variable "alert_email" { type = string }

data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "parser" {
  name              = "/aws/lambda/${var.project_name}-agenda-parser"
  retention_in_days = 14
}

data "aws_iam_policy_document" "parser_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "parser" {
  assume_role_policy = data.aws_iam_policy_document.parser_assume_role.json
  inline_policy {
    name = "WriteLogs"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-agenda-parser:*"
      }]
    })
  }
}

resource "aws_lambda_function" "parser" {
  function_name = "${var.project_name}-agenda-parser"
  package_type  = "Image"
  image_uri     = var.image_uri
  architectures = ["arm64"]
  memory_size   = 512
  timeout       = 30
  role          = aws_iam_role.parser.arn
  publish       = false

  image_config {
    entry_point = ["python", "-m", "awslambdaric"]
    command     = ["app.ai.agenda_lambda.handler"]
  }
  logging_config {
    log_group  = aws_cloudwatch_log_group.parser.name
    log_format = "Text"
  }
  environment {
    variables = {
      PARSER_MODEL          = var.parser_model
      CLOUDFLARE_ACCOUNT_ID = var.cloudflare_account_id
      CLOUDFLARE_API_TOKEN  = var.cloudflare_api_token
      COGNITO_USER_POOL_ID  = var.cognito_user_pool_id
      COGNITO_CLIENT_ID     = var.cognito_client_id
    }
  }

  # Prevent the import run from pushing credentials back to the existing function. Remove
  # this temporary ignore after import, then rotate the Cloudflare token through Terraform.
  lifecycle {
    ignore_changes = [
      environment[0].variables["CLOUDFLARE_ACCOUNT_ID"],
      environment[0].variables["CLOUDFLARE_API_TOKEN"],
    ]
  }
}

resource "aws_lambda_function_url" "parser" {
  function_name      = aws_lambda_function.parser.function_name
  authorization_type = "NONE"
  cors {
    allow_origins = var.cors_origins
    allow_methods = ["POST"]
    allow_headers = ["authorization", "content-type"]
    max_age       = 600
  }
}

resource "aws_lambda_permission" "parser_url" {
  statement_id           = "new-project-ai-ParserUrlPermission-zyQC2ekwOVTC"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.parser.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}

resource "aws_lambda_permission" "parser_invoke" {
  statement_id             = "new-project-ai-ParserInvokePermission-ZoAee6refJ3o"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.parser.function_name
  principal                = "*"
  invoked_via_function_url = true
}

resource "aws_budgets_budget" "monthly" {
  name         = "${var.project_name}-monthly-5-dollar-limit"
  budget_type  = "COST"
  limit_amount = "5"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"
  tags         = { PROJECT_NAME = var.project_name }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }

  # Keep the import run limited to state adoption. Remove after importing and decide whether
  # the existing budget should receive the PROJECT_NAME tag as a separate change.
  lifecycle {
    ignore_changes = [tags]
  }
}

output "parser_url" { value = aws_lambda_function_url.parser.function_url }
output "parser_log_group" { value = aws_cloudwatch_log_group.parser.name }
