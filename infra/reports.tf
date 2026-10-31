# Weekly reports resources migrated from the Lab 5 CloudFormation stack.
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
