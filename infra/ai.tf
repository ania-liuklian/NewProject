# Agenda parser resources migrated from the Lab 6 CloudFormation stack.
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
