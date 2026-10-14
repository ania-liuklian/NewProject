"""SQS and EventBridge entry point for building reports."""

import json
import logging
import os
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

import boto3

from app.reports.weekly import build_weekly_report

log = logging.getLogger()
log.setLevel(logging.INFO)
s3 = boto3.client("s3")


def _last_week() -> str:
    today = datetime.now(ZoneInfo("Europe/Kyiv")).date()
    monday = today - timedelta(days=today.weekday())
    return (monday - timedelta(days=7)).strftime("%G-W%V")


def handler(event: dict, context: object) -> dict:
    records = event.get("Records", [])
    if records and records[0].get("eventSource") == "aws:sqs":
        payload = json.loads(records[0]["body"])
        trigger = "schedule" if payload.get("source") == "schedule" else "sqs"
    else:
        payload = event
        trigger = "schedule" if payload.get("source") == "schedule" else "direct"
    week = payload.get("week") or _last_week()
    log.info("report-builder triggered trigger=%s week=%s", trigger, week)
    content = build_weekly_report(week)
    key = f"reports/{week}.csv"
    s3.put_object(Bucket=os.environ["REPORTS_BUCKET"], Key=key, Body=content, ContentType="text/csv; charset=utf-8")
    log.info("report-builder uploaded trigger=%s week=%s key=%s", trigger, week, key)
    return {"key": key, "week": week}
