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

module "auth" {
  source = "./modules/auth"

  project_name         = var.project_name
  app_urls             = local.browser_origins
  google_client_id     = var.google_client_id
  google_client_secret = var.google_client_secret
}

module "reports" {
  source = "./modules/reports"

  project_name      = var.project_name
  aws_region        = var.aws_region
  image_uri         = data.aws_lambda_function.report_builder.image_uri
  database_endpoint = data.aws_cloudformation_stack.backend.outputs["DatabaseEndpoint"]
  database_port     = tonumber(data.aws_cloudformation_stack.backend.outputs["DatabasePort"])
  database_name     = data.aws_cloudformation_stack.backend.outputs["DatabaseName"]
  database_user     = data.aws_cloudformation_stack.backend.outputs["DatabaseUser"]
  database_password = data.aws_ssm_parameter.database_password.value
  subnet_ids = [
    data.aws_cloudformation_stack.backend.outputs["PrivateSubnetA"],
    data.aws_cloudformation_stack.backend.outputs["PrivateSubnetB"],
  ]
  security_group_id = data.aws_cloudformation_stack.backend.outputs["FunctionSecurityGroup"]
  email_from        = var.reports_email_from
  email_to          = var.reports_email_to
}

module "ai" {
  source = "./modules/ai"

  project_name          = var.project_name
  aws_region            = var.aws_region
  image_uri             = data.aws_lambda_function.parser.image_uri
  cognito_user_pool_id  = module.auth.user_pool_id
  cognito_client_id     = module.auth.user_pool_client_id
  cors_origins          = distinct(local.parser_origins)
  parser_model          = var.parser_model
  cloudflare_account_id = var.cloudflare_account_id
  cloudflare_api_token  = var.cloudflare_api_token
  alert_email           = var.alert_email
}
