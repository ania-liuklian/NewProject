#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source infra/common.sh
: "${REPORT_WEEK:?Usage: make report-now WEEK=YYYY-Www}"
queue_url="$(aws cloudformation describe-stacks --stack-name "$PROJECT_NAME-reports" \
  --query "Stacks[0].Outputs[?OutputKey=='ReportsQueueUrl'].OutputValue" --output text)"
if [ -z "$queue_url" ] || [ "$queue_url" = "None" ]; then
  echo "Reports stack not found; run make deploy-reports first." >&2
  exit 1
fi
aws sqs send-message --queue-url "$queue_url" \
  --message-body "{\"week\":\"$REPORT_WEEK\",\"source\":\"make\"}"
