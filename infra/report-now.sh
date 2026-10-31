#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ -f .env ]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi
: "${REPORT_WEEK:?Usage: make report-now WEEK=YYYY-Www}"
queue_url="$(terraform -chdir=infra output -raw reports_queue_url)"
aws sqs send-message --queue-url "$queue_url" \
  --message-body "{\"week\":\"$REPORT_WEEK\",\"source\":\"make\"}"
