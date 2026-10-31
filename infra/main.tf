# This root owns only the three stacks being migrated from CloudFormation. The existing
# network/backend/frontend stacks stay in CloudFormation and are read as data sources.
data "aws_cloudformation_stack" "backend" {
  name = "${var.project_name}-backend"
}

data "aws_cloudformation_stack" "frontend" {
  name = "${var.project_name}-frontend"
}

data "aws_ssm_parameter" "database_password" {
  name            = "/${var.project_name}/db-password"
  with_decryption = true
}

# Keep each imported Lambda on its current image during the ownership handoff. The existing
# report builder and mailer use the same image; the parser was deployed from a later image.
data "aws_lambda_function" "report_builder" {
  function_name = "${var.project_name}-report-builder"
}

data "aws_lambda_function" "parser" {
  function_name = "${var.project_name}-agenda-parser"
}

locals {
  app_urls = compact([
    data.aws_cloudformation_stack.frontend.outputs["AppUrl"],
    var.domain_name == "" ? "" : "https://${var.domain_name}",
  ])
  browser_origins = concat(["http://localhost:5173", "http://localhost:3000"], local.app_urls)
  parser_origins  = concat(local.app_urls, compact(split(",", replace(var.extra_cors_origins, " ", ""))))
}
