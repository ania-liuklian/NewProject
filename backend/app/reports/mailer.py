"""S3 event handler that emails a newly created report as an attachment."""

import logging
import os
from email.message import EmailMessage
from urllib.parse import unquote_plus

import boto3

log = logging.getLogger()
log.setLevel(logging.INFO)
s3 = boto3.client("s3")
ses = boto3.client("sesv2")


def handler(event: dict, context: object) -> None:
    for record in event.get("Records", []):
        if record.get("eventSource") != "aws:s3":
            continue
        bucket = record["s3"]["bucket"]["name"]
        key = unquote_plus(record["s3"]["object"]["key"])
        log.info("report-mailer triggered trigger=s3 bucket=%s key=%s", bucket, key)
        data = s3.get_object(Bucket=bucket, Key=key)["Body"].read()
        filename = key.rsplit("/", 1)[-1]
        message = EmailMessage()
        message["Subject"] = f"Weekly meetings report: {filename.removesuffix('.csv')}"
        message["From"] = os.environ["REPORTS_EMAIL_FROM"]
        message["To"] = os.environ["REPORTS_EMAIL_TO"]
        message.set_content(f"Your weekly meetings report is attached: {filename}\n")
        message.add_attachment(data, maintype="text", subtype="csv", filename=filename)
        ses.send_email(
            FromEmailAddress=os.environ["REPORTS_EMAIL_FROM"],
            Destination={"ToAddresses": [address.strip() for address in os.environ["REPORTS_EMAIL_TO"].split(",")]},
            Content={"Raw": {"Data": message.as_bytes()}},
        )
        log.info("report-mailer sent trigger=s3 key=%s", key)
