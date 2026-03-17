import json
import logging
import os
from email.mime.application import MIMEApplication
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

import boto3
from botocore.exceptions import BotoCoreError, ClientError


LOGGER = logging.getLogger()
LOGGER.setLevel(logging.INFO)

SES_CLIENT = boto3.client("ses", region_name=os.environ.get("SES_REGION"))
S3_CLIENT = boto3.client("s3")
S3_BUCKET = os.environ.get("S3_BUCKET", "attestry-dev-assets")

FROM_EMAIL_ADDRESS = os.environ["FROM_EMAIL_ADDRESS"]
REPLY_TO_ADDRESS = os.environ.get("REPLY_TO_ADDRESS", "").strip()
SUBJECT_PREFIX = os.environ.get("SUBJECT_PREFIX", "").strip()
INVITATION_TYPE = "INVITATION"
SIGNUP_EMAIL_VERIFICATION_TYPE = "SIGNUP_EMAIL_VERIFICATION"
PASSPORT_MANUAL_DELIVERY_TYPE = "PASSPORT_MANUAL_DELIVERY"


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

    if message_type == INVITATION_TYPE:
        process_invitation(body)
    elif message_type == SIGNUP_EMAIL_VERIFICATION_TYPE:
        process_signup_verification(body)
    elif message_type == PASSPORT_MANUAL_DELIVERY_TYPE:
        process_passport_manual_delivery(body)
    else:
        LOGGER.info("Skipping unsupported message type: %s", message_type)


def process_invitation(body):
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


def process_signup_verification(body):
    verification_id = require_field(body, "verificationId")
    email = require_field(body, "email")
    code = require_field(body, "code")
    expires_in = body.get("expiresInSeconds", 600)
    expires_min = expires_in // 60

    subject = build_verification_subject()
    text_body = build_verification_text_body(code, expires_min)
    html_body = build_verification_html_body(code, expires_min)

    send_email(email, subject, text_body, html_body)

    LOGGER.info(
        "Signup verification email sent for verificationId=%s email=%s",
        verification_id,
        email,
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


def process_passport_manual_delivery(body):
    passport_id = require_field(body, "passportId")
    tenant_id = body.get("tenantId", "")
    recipient_email = require_field(body, "recipientEmail")
    serial_number = body.get("serialNumber", "")
    model_name = body.get("modelName", "")
    message = body.get("message", "")
    attachments = body.get("attachments", [])

    subject = build_passport_manual_subject(model_name)
    text_body = build_passport_manual_text_body(serial_number, model_name, message)
    html_body = build_passport_manual_html_body(serial_number, model_name, message)

    if attachments:
        send_email_with_attachments(recipient_email, subject, text_body, html_body, attachments)
    else:
        send_email(recipient_email, subject, text_body, html_body)

    LOGGER.info(
        "Passport manual delivery email sent for passportId=%s tenantId=%s recipientEmail=%s attachments=%d",
        passport_id,
        tenant_id,
        recipient_email,
        len(attachments),
    )


def build_passport_manual_subject(model_name):
    base_subject = f"[Attestry] Your Digital Passport for {model_name}"
    return f"{SUBJECT_PREFIX} {base_subject}".strip() if SUBJECT_PREFIX else base_subject


def build_passport_manual_text_body(serial_number, model_name, message):
    body = (
        f"Your digital passport for {model_name} is ready.\n\n"
        f"Serial Number: {serial_number}\n"
    )
    if message:
        body += f"\nMessage: {message}\n"
    return body


def build_passport_manual_html_body(serial_number, model_name, message):
    message_html = f"<p><strong>Message:</strong> {message}</p>" if message else ""
    return f"""
    <html>
      <body>
        <p>Your digital passport for <strong>{model_name}</strong> is ready.</p>
        <ul>
          <li><strong>Serial Number:</strong> {serial_number}</li>
        </ul>
        {message_html}
      </body>
    </html>
    """.strip()


def build_verification_subject():
    base_subject = "[Attestry] Email Verification Code"
    return f"{SUBJECT_PREFIX} {base_subject}".strip() if SUBJECT_PREFIX else base_subject


def build_verification_text_body(code, expires_min):
    return (
        "Your email verification code is below.\n\n"
        f"Verification Code: {code}\n"
        f"This code expires in {expires_min} minutes.\n"
    )


def build_verification_html_body(code, expires_min):
    return f"""
    <html>
      <body>
        <p>Your email verification code is below.</p>
        <p style="font-size:24px;font-weight:bold;letter-spacing:4px;">{code}</p>
        <p>This code expires in {expires_min} minutes.</p>
      </body>
    </html>
    """.strip()


def send_email_with_attachments(recipient, subject, text_body, html_body, attachments):
    msg = MIMEMultipart("mixed")
    msg["Subject"] = subject
    msg["From"] = FROM_EMAIL_ADDRESS
    msg["To"] = recipient
    if REPLY_TO_ADDRESS:
        msg["Reply-To"] = REPLY_TO_ADDRESS

    body_part = MIMEMultipart("alternative")
    body_part.attach(MIMEText(text_body, "plain", "utf-8"))
    body_part.attach(MIMEText(html_body, "html", "utf-8"))
    msg.attach(body_part)

    for att in attachments:
        object_key = att.get("objectKey")
        file_name = att.get("fileName", "attachment")
        content_type = att.get("contentType", "application/octet-stream")

        if not object_key:
            LOGGER.warning("Skipping attachment with missing objectKey")
            continue

        try:
            s3_obj = S3_CLIENT.get_object(Bucket=S3_BUCKET, Key=object_key)
            file_data = s3_obj["Body"].read()
        except (BotoCoreError, ClientError) as exc:
            LOGGER.error("Failed to download S3 object %s: %s", object_key, exc)
            continue

        maintype, _, subtype = content_type.partition("/")
        att_part = MIMEApplication(file_data, _subtype=subtype if subtype else "octet-stream")
        att_part.add_header("Content-Disposition", "attachment", filename=file_name)
        msg.attach(att_part)

    try:
        SES_CLIENT.send_raw_email(
            Source=FROM_EMAIL_ADDRESS,
            Destinations=[recipient],
            RawMessage={"Data": msg.as_string()},
        )
    except (BotoCoreError, ClientError) as exc:
        raise RuntimeError("SES send_raw_email failed") from exc


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
