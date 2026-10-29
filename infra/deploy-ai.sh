#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/common.sh
require_auth_stack
stack_exists "$BACKEND_STACK" || { echo "Run make deploy-backend first." >&2; exit 1; }
alert_email="${REPORTS_EMAIL_TO:-}"
: "${alert_email:?Set REPORTS_EMAIL_TO in .env for the $5 monthly AWS budget alert}"
: "${CLOUDFLARE_ACCOUNT_ID:?Set CLOUDFLARE_ACCOUNT_ID in .env}"
: "${CLOUDFLARE_API_TOKEN:?Set CLOUDFLARE_API_TOKEN in .env}"

repository="$(output "$ECR_STACK" RepositoryUri)"
tag="$(aws ecr describe-images --repository-name "$PROJECT_NAME-backend" \
  --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --output text)"
image="$repository:$tag"
origins="$(cors_origins)"
parser_model="${PARSER_MODEL:-@cf/meta/llama-3.3-70b-instruct-fp8-fast}"
aws cloudformation deploy \
  --stack-name "$PROJECT_NAME-ai" \
  --template-file infra/ai.yml \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    "ProjectName=$PROJECT_NAME" "ImageUri=$image" \
    "CognitoUserPoolId=$(output "$AUTH_STACK" UserPoolId)" \
    "CognitoClientId=$(output "$AUTH_STACK" UserPoolClientId)" \
    "CorsOrigins=$origins" "ParserModel=$parser_model" \
    "CloudflareAccountId=$CLOUDFLARE_ACCOUNT_ID" "CloudflareApiToken=$CLOUDFLARE_API_TOKEN" \
    "AlertEmail=$alert_email" \
  --tags "${STACK_TAGS[@]}" \
  --no-fail-on-empty-changeset
echo "Parser URL: $(output "$PROJECT_NAME-ai" ParserUrl)"
echo "Parser logs: $(output "$PROJECT_NAME-ai" ParserLogGroup)"
