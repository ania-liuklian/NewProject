#!/usr/bin/env bash
# Prints the S3 reports listing and one CloudWatch trigger line for each lab trigger.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi
bucket="$(terraform -chdir=infra output -raw reports_bucket)"

start_time_ms="$(( $(date -u -d '14 days ago' +%s) * 1000 ))"
builder_group="/aws/lambda/$PROJECT_NAME-report-builder"
mailer_group="/aws/lambda/$PROJECT_NAME-report-mailer"

echo "==> S3 reports in s3://$bucket/reports/"
aws s3 ls "s3://$bucket/reports/" --recursive

print_trigger() {
  local group="$1" trigger="$2"
  local messages
  messages="$(aws logs filter-log-events \
    --log-group-name "$group" \
    --start-time "$start_time_ms" \
    --filter-pattern "\"trigger=$trigger\"" \
    --query 'events[].message' \
    --output text)"
  if [ -z "$messages" ] || [ "$messages" = "None" ]; then
    echo "No trigger=$trigger log found in $group (last 14 days)." >&2
    return 1
  fi
  # Keep the newest matching line as the submission example.
  printf '%s\n' "$messages" | tail -n 1
}

echo "==> Required CloudWatch trigger lines"
missing=0
print_trigger "$builder_group" schedule || missing=1
print_trigger "$builder_group" sqs || missing=1
print_trigger "$mailer_group" s3 || missing=1
if [ "$missing" -ne 0 ]; then
  echo "Some trigger lines are missing; run this command again after those events occur." >&2
  exit 1
fi
