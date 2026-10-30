output "app_url" {
  value = module.frontend.app_url
}

output "custom_domain_url" {
  value = module.frontend.custom_domain_url
}

output "distribution_domain" {
  description = "Target for a CNAME record when the custom domain's DNS is not in Route 53"
  value       = module.frontend.distribution_domain
}

output "certificate_validation_record" {
  description = "DNS record that proves ownership of the custom domain (add it yourself without Route 53)"
  value       = module.frontend.certificate_validation_record
}

output "api_url" {
  value = "${module.backend.api_base_url}/api"
}

output "docs_url" {
  value = "${module.backend.api_base_url}/api/docs"
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
