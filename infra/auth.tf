# Cognito resources migrated from the Lab 4 CloudFormation stack.
module "auth" {
  source = "./modules/auth"

  project_name         = var.project_name
  app_urls             = local.browser_origins
  google_client_id     = var.google_client_id
  google_client_secret = var.google_client_secret
}
