output "app_url" {
  value = data.aws_cloudformation_stack.frontend.outputs["AppUrl"]
}

output "custom_domain_url" {
  value = var.domain_name == "" ? "" : "https://${var.domain_name}"
}

output "distribution_domain" {
  description = "Target for a CNAME record when the custom domain's DNS is not in Route 53"
  value       = data.aws_cloudformation_stack.frontend.outputs["DistributionDomain"]
}

output "api_url" {
  value = data.aws_cloudformation_stack.backend.outputs["ApiUrl"]
}

output "docs_url" {
  value = data.aws_cloudformation_stack.backend.outputs["DocsUrl"]
}

output "cognito_user_pool_id" {
  value = module.auth.user_pool_id
}

output "cognito_client_id" {
  value = module.auth.user_pool_client_id
}

output "cognito_domain" {
  description = "Cognito domain for OAuth redirects (Google)"
  value       = module.auth.domain
}

output "cognito_google_enabled" {
  value = module.auth.google_enabled
}

output "reports_bucket" {
  value = module.reports.bucket_name
}

output "reports_queue_url" {
  value = module.reports.queue_url
}

output "reports_dlq_url" {
  value = module.reports.dlq_url
}

output "reports_builder_log_group" {
  value = module.reports.builder_log_group
}

output "reports_mailer_log_group" {
  value = module.reports.mailer_log_group
}

output "agenda_parser_url" {
  value = module.ai.parser_url
}

output "agenda_parser_log_group" {
  value = module.ai.parser_log_group
}
