# IDs were read from CloudFormation in eu-central-1. Keep these imports until the HCP
# import run completes and a subsequent plan reports no changes.

import {
  to = module.auth.aws_cognito_user_pool.this
  id = "eu-central-1_tgOX2DRzy"
}

import {
  to = module.auth.aws_cognito_user_pool_domain.this
  id = "new-project-454005357357"
}

import {
  to = module.auth.aws_cognito_identity_provider.google[0]
  id = "eu-central-1_tgOX2DRzy:Google"
}

import {
  to = module.auth.aws_cognito_user_pool_client.web
  id = "eu-central-1_tgOX2DRzy/771oshd59jrfu365n1cuguc5qa"
}

import {
  to = module.auth.aws_cognito_managed_login_branding.this
  id = "eu-central-1_tgOX2DRzy,00011fcd-4ba9-4965-8895-2f6fa8aa9d9f"
}

import {
  to = module.reports.aws_s3_bucket.reports
  id = "new-project-reports-454005357357"
}

import {
  to = module.reports.aws_s3_bucket_public_access_block.reports
  id = "new-project-reports-454005357357"
}

import {
  to = module.reports.aws_s3_bucket_lifecycle_configuration.reports
  id = "new-project-reports-454005357357"
}

import {
  to = module.reports.aws_s3_bucket_notification.reports
  id = "new-project-reports-454005357357"
}

import {
  to = module.reports.aws_sqs_queue.reports_dlq
  id = "https://sqs.eu-central-1.amazonaws.com/454005357357/new-project-report-requests-dlq"
}

import {
  to = module.reports.aws_sqs_queue.reports
  id = "https://sqs.eu-central-1.amazonaws.com/454005357357/new-project-report-requests"
}

import {
  to = module.reports.aws_cloudwatch_log_group.builder
  id = "/aws/lambda/new-project-report-builder"
}

import {
  to = module.reports.aws_cloudwatch_log_group.mailer
  id = "/aws/lambda/new-project-report-mailer"
}

import {
  to = module.reports.aws_iam_role.builder
  id = "new-project-reports-BuilderRole-DJPiiTLJzbYl"
}

import {
  to = module.reports.aws_iam_role.mailer
  id = "new-project-reports-MailerRole-DLn2mEzc0Yjo"
}

import {
  to = module.reports.aws_iam_role.scheduler
  id = "new-project-reports-ScheduleRole-SZbWnFCPOkOw"
}

import {
  to = module.reports.aws_lambda_function.builder
  id = "new-project-report-builder"
}

import {
  to = module.reports.aws_lambda_function.mailer
  id = "new-project-report-mailer"
}

import {
  to = module.reports.aws_lambda_event_source_mapping.queue_builder
  id = "e6e42733-cbda-42ce-97d2-d3098c3d0ca9"
}

import {
  to = module.reports.aws_scheduler_schedule.weekly
  id = "default/new-project-weekly-report"
}

import {
  to = module.reports.aws_lambda_permission.bucket_invoke_mailer
  id = "new-project-report-mailer/new-project-reports-MailerInvokePermission-G2CCVhIg9jBW"
}

import {
  to = module.ai.aws_cloudwatch_log_group.parser
  id = "/aws/lambda/new-project-agenda-parser"
}

import {
  to = module.ai.aws_iam_role.parser
  id = "new-project-ai-ParserRole-own37ngJiA7h"
}

import {
  to = module.ai.aws_lambda_function.parser
  id = "new-project-agenda-parser"
}

import {
  to = module.ai.aws_lambda_function_url.parser
  id = "new-project-agenda-parser"
}

import {
  to = module.ai.aws_lambda_permission.parser_url
  id = "new-project-agenda-parser/new-project-ai-ParserUrlPermission-zyQC2ekwOVTC"
}

import {
  to = module.ai.aws_lambda_permission.parser_invoke
  id = "new-project-agenda-parser/new-project-ai-ParserInvokePermission-ZoAee6refJ3o"
}

import {
  to = module.ai.aws_budgets_budget.monthly
  id = "454005357357:new-project-monthly-5-dollar-limit"
}
