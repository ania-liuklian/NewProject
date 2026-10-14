#!/usr/bin/env bash
# Deploys the asynchronous report pipeline. The backend image is built by make deploy-backend.
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/common.sh
: "${REPORTS_EMAIL_FROM:?Set REPORTS_EMAIL_FROM in .env}"
: "${REPORTS_EMAIL_TO:?Set REPORTS_EMAIL_TO in .env}"

if ! stack_exists "$BACKEND_STACK"; then
  echo "Backend stack not found; run make deploy-backend first." >&2
  exit 1
fi
repository="$(output "$ECR_STACK" RepositoryUri)"
tag="$(aws ecr describe-images --repository-name "$PROJECT_NAME-backend" \
  --query 'sort_by(imageDetails,&imagePushedAt)[-1].imageTags[0]' --output text)"
image="$repository:$tag"
db_password="$(aws ssm get-parameter --name "/$PROJECT_NAME/db-password" --with-decryption \
  --query Parameter.Value --output text)"

# A failed change-set creation can leave an empty REVIEW_IN_PROGRESS stack; a failed resource
# creation leaves ROLLBACK_COMPLETE. Neither can be updated, so remove the empty stack and retry.
if stack_exists "$PROJECT_NAME-reports"; then
  reports_status="$(aws cloudformation describe-stacks --stack-name "$PROJECT_NAME-reports" \
    --query 'Stacks[0].StackStatus' --output text)"
  if [ "$reports_status" = "ROLLBACK_COMPLETE" ] || [ "$reports_status" = "REVIEW_IN_PROGRESS" ]; then
    echo "==> Removing incomplete reports stack ($reports_status) before retry"
    aws cloudformation delete-stack --stack-name "$PROJECT_NAME-reports"
    aws cloudformation wait stack-delete-complete --stack-name "$PROJECT_NAME-reports"
  fi
fi

aws cloudformation deploy \
  --stack-name "$PROJECT_NAME-reports" \
  --template-file infra/reports.yaml \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides \
    "ProjectName=$PROJECT_NAME" \
    "ImageUri=$image" \
    "DBPassword=$db_password" \
    "EmailFrom=$REPORTS_EMAIL_FROM" \
    "EmailTo=$REPORTS_EMAIL_TO" \
  --tags "${STACK_TAGS[@]}" \
  --no-fail-on-empty-changeset

echo "Reports bucket: $(output "$PROJECT_NAME-reports" ReportsBucket)"
echo "Builder logs:   $(output "$PROJECT_NAME-reports" BuilderLogGroup)"
echo "Mailer logs:    $(output "$PROJECT_NAME-reports" MailerLogGroup)"
echo "Verify $REPORTS_EMAIL_FROM in Amazon SES; SES will send it a verification email."
