import json
import logging
import os

import boto3
from botocore.exceptions import BotoCoreError, ClientError


LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

SES_CLIENT = boto3.client("ses", region_name=os.environ.get("SES_REGION"))

FROM_EMAIL_ADDRESS = os.environ["FROM_EMAIL_ADDRESS"]
REPLY_TO_ADDRESS = os.environ.get("REPLY_TO_ADDRESS", "").strip()
SUBJECT_PREFIX = os.environ.get("SUBJECT_PREFIX", "").strip()
INVITATION_TYPE = "INVITATION"


def lambda_handler(event, _context):
    failures = []

    for record in event.get("Records", []):
        message_id = record["messageId"]

        try:
            process_record(record)
        except Exception:
            LOGGER.exception("Failed to process SQS record %s", message_id)
            failures.append({"itemIdentifier": message_id})

    return {"batchItemFailures": failures}


def process_record(record):
    body = json.loads(record["body"])
    message_type = body.get("type")

    if message_type != INVITATION_TYPE:
        LOGGER.info("Skipping unsupported message type: %s", message_type)
        return

    invitation_id = require_field(body, "invitationId")
    tenant_id = require_field(body, "tenantId")
    invitee_email = require_field(body, "inviteeEmail")
    accept_url = require_field(body, "acceptUrl")

    subject = build_subject()
    text_body = build_text_body(invitation_id, tenant_id, accept_url)
    html_body = build_html_body(invitation_id, tenant_id, accept_url)

    send_email(invitee_email, subject, text_body, html_body)

    LOGGER.info(
        "Invitation email sent for invitationId=%s tenantId=%s inviteeEmail=%s",
        invitation_id,
        tenant_id,
        invitee_email,
    )


def require_field(payload, field_name):
    value = payload.get(field_name)
    if not value:
        raise ValueError(f"Missing required field: {field_name}")
    return value


def build_subject():
    base_subject = "[Attestry] Invitation to join tenant"
    return f"{SUBJECT_PREFIX} {base_subject}".strip() if SUBJECT_PREFIX else base_subject


def build_text_body(invitation_id, tenant_id, accept_url):
    return (
        "You have been invited to join an Attestry tenant.\n\n"
        f"Invitation ID: {invitation_id}\n"
        f"Tenant ID: {tenant_id}\n"
        f"Accept URL: {accept_url}\n"
    )


def build_html_body(invitation_id, tenant_id, accept_url):
    return f"""
    <html>
      <body>
        <p>You have been invited to join an Attestry tenant.</p>
        <ul>
          <li><strong>Invitation ID:</strong> {invitation_id}</li>
          <li><strong>Tenant ID:</strong> {tenant_id}</li>
          <li><strong>Accept URL:</strong> <a href="{accept_url}">{accept_url}</a></li>
        </ul>
      </body>
    </html>
    """.strip()


def send_email(recipient, subject, text_body, html_body):
    request = {
        "Source": FROM_EMAIL_ADDRESS,
        "Destination": {"ToAddresses": [recipient]},
        "Message": {
            "Subject": {"Data": subject, "Charset": "UTF-8"},
            "Body": {
                "Text": {"Data": text_body, "Charset": "UTF-8"},
                "Html": {"Data": html_body, "Charset": "UTF-8"},
            },
        },
    }

    if REPLY_TO_ADDRESS:
        request["ReplyToAddresses"] = [REPLY_TO_ADDRESS]

    try:
        SES_CLIENT.send_email(**request)
    except (BotoCoreError, ClientError) as exc:
        raise RuntimeError("SES send_email failed") from exc
