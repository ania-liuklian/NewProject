# Terraform import checklist (Labs 4–6)

The IDs below are read from the AWS account that owns the existing stacks. Do not guess them.
The Terraform addresses are the destinations declared in the current configuration.

The migration root manages only Cognito, reports, and AI. The existing backend/database,
frontend, network, and ECR stacks remain CloudFormation-managed and are read through data sources
or direct Lambda lookups. Do not import those stacks into this migration workspace.

## Cognito

| Resource | Terraform address | Import ID format |
|---|---|---|
| User pool | `module.auth.aws_cognito_user_pool.this` | User pool ID, e.g. `us-east-1_...` |
| User pool domain | `module.auth.aws_cognito_user_pool_domain.this` | Domain name/prefix |
| Google identity provider (if enabled) | `module.auth.aws_cognito_identity_provider.google[0]` | `<pool-id>:Google` |
| Web app client | `module.auth.aws_cognito_user_pool_client.web` | `<pool-id>/<client-id>` |
| Managed Login branding | `module.auth.aws_cognito_managed_login_branding.this` | `<pool-id>/<client-id>`; confirm against provider docs for the installed AWS provider |

## Reports

| Resource | Terraform address | Import ID format |
|---|---|---|
| S3 reports bucket | `module.reports.aws_s3_bucket.reports` | Bucket name |
| S3 public access block | `module.reports.aws_s3_bucket_public_access_block.reports` | Bucket name |
| S3 lifecycle configuration | `module.reports.aws_s3_bucket_lifecycle_configuration.reports` | Bucket name |
| S3 notifications | `module.reports.aws_s3_bucket_notification.reports` | Bucket name |
| DLQ and request queue | `module.reports.aws_sqs_queue.reports_dlq`, `module.reports.aws_sqs_queue.reports` | Queue URL |
| Builder and mailer log groups | `module.reports.aws_cloudwatch_log_group.builder`, `module.reports.aws_cloudwatch_log_group.mailer` | Log group name |
| Builder, mailer, scheduler roles | `module.reports.aws_iam_role.builder`, `module.reports.aws_iam_role.mailer`, `module.reports.aws_iam_role.scheduler` | IAM role name from CloudFormation physical resource ID |
| Builder and mailer Lambdas | `module.reports.aws_lambda_function.builder`, `module.reports.aws_lambda_function.mailer` | Function name |
| Queue event source mapping | `module.reports.aws_lambda_event_source_mapping.queue_builder` | Event source mapping UUID |
| Weekly schedule | `module.reports.aws_scheduler_schedule.weekly` | `default/<schedule-name>` |
| S3 invoke permission | `module.reports.aws_lambda_permission.bucket_invoke_mailer` | Provider-specific function/statement ID |

## Agenda parser

| Resource | Terraform address | Import ID format |
|---|---|---|
| Parser log group | `module.ai.aws_cloudwatch_log_group.parser` | Log group name |
| Parser role | `module.ai.aws_iam_role.parser` | IAM role name from CloudFormation physical resource ID |
| Parser Lambda | `module.ai.aws_lambda_function.parser` | Function name |
| Function URL | `module.ai.aws_lambda_function_url.parser` | Function name |
| URL permissions | `module.ai.aws_lambda_permission.parser_url`, `module.ai.aws_lambda_permission.parser_invoke` | Provider-specific function/statement ID |
| Monthly budget | `module.ai.aws_budgets_budget.monthly` | Provider-specific budget import ID |

S3 bucket notifications are a single atomic configuration. Import the existing notification
before applying; the provider warns that an apply can replace the bucket's complete notification
configuration. See the [AWS provider import docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification).

For each resource, check the AWS provider page for the installed provider version. Add the
`import { to = ... id = "..." }` blocks to a temporary `infra/imports.tf`, run a plan, and fix
HCL until the plan shows imports only and no add/change/destroy. Apply the import through HCP
Terraform, run a fresh plan, and keep the output only when it reports no changes. Remove the
temporary import file after the import is recorded in remote state.

Useful read-only AWS commands for stack IDs and outputs:

```sh
aws cloudformation describe-stacks --stack-name "$PROJECT_NAME-auth"
aws cloudformation describe-stack-resources --stack-name "$PROJECT_NAME-reports"
aws cloudformation describe-stack-resources --stack-name "$PROJECT_NAME-ai"
```
