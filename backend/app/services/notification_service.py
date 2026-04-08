from dataclasses import dataclass
from typing import Any

from flask import current_app

try:
    from twilio.base.exceptions import TwilioRestException
    from twilio.rest import Client
except ImportError:  # pragma: no cover - local fallback if dependency not installed yet
    Client = None
    TwilioRestException = Exception

from .caregiver_service import normalize_notification_channel, normalize_phone_number
from .timezone_service import datetime_to_local_iso


@dataclass
class NotificationResult:
    channel: str
    success: bool
    target: str
    sid: str | None = None
    error: str | None = None


def _twilio_client() -> Any | None:
    account_sid = current_app.config.get("TWILIO_ACCOUNT_SID")
    auth_token = current_app.config.get("TWILIO_AUTH_TOKEN")
    if not account_sid or not auth_token or Client is None:
        return None
    return Client(account_sid, auth_token)


def _send_twilio_message(*, to_number: str, body: str, from_number: str) -> NotificationResult:
    client = _twilio_client()
    if client is None:
        return NotificationResult(
            channel="unknown",
            success=False,
            target=to_number,
            error="Twilio is not configured. Set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN.",
        )

    try:
        message = client.messages.create(
            body=body,
            from_=from_number,
            to=to_number,
        )
    except TwilioRestException as error:
        return NotificationResult(
            channel="unknown",
            success=False,
            target=to_number,
            error=str(error),
        )

    return NotificationResult(
        channel="unknown",
        success=True,
        target=to_number,
        sid=message.sid,
    )


def send_sms_notification(phone_number: str, body: str) -> NotificationResult:
    normalized = normalize_phone_number(phone_number)
    sms_from = current_app.config.get("TWILIO_SMS_FROM")

    if not normalized:
        return NotificationResult(
            channel="sms",
            success=False,
            target=phone_number,
            error="Invalid caregiver phone number.",
        )
    if not sms_from:
        return NotificationResult(
            channel="sms",
            success=False,
            target=normalized,
            error="TWILIO_SMS_FROM is not configured.",
        )

    result = _send_twilio_message(to_number=normalized, body=body, from_number=sms_from)
    result.channel = "sms"
    return result


def send_whatsapp_notification(phone_number: str, body: str) -> NotificationResult:
    normalized = normalize_phone_number(phone_number)
    whatsapp_from = current_app.config.get("TWILIO_WHATSAPP_FROM")

    if not normalized:
        return NotificationResult(
            channel="whatsapp",
            success=False,
            target=phone_number,
            error="Invalid caregiver phone number.",
        )
    if not whatsapp_from:
        return NotificationResult(
            channel="whatsapp",
            success=False,
            target=normalized,
            error="TWILIO_WHATSAPP_FROM is not configured.",
        )

    result = _send_twilio_message(
        to_number=f"whatsapp:{normalized}",
        body=body,
        from_number=whatsapp_from,
    )
    result.channel = "whatsapp"
    return result


def notify_caregiver(phone_number: str, message: str, channel: str | None = None) -> list[NotificationResult]:
    normalized_channel = normalize_notification_channel(
        channel,
        default=current_app.config.get("DEFAULT_CAREGIVER_NOTIFICATION_CHANNEL", "sms"),
    )

    results: list[NotificationResult] = []
    if normalized_channel in {"sms", "both"}:
        results.append(send_sms_notification(phone_number, message))
    if normalized_channel in {"whatsapp", "both"}:
        results.append(send_whatsapp_notification(phone_number, message))
    return results


def send_caregiver_invitation(
    phone_number: str,
    full_name: str,
    otp_code: str,
    otp_expires_at=None,
    timezone_name: str | None = None,
) -> NotificationResult:
    expiry_text = ""
    if otp_expires_at is not None:
        local_expiry = datetime_to_local_iso(otp_expires_at, timezone_name)
        if local_expiry:
            expiry_text = f" OTP expires at {local_expiry}."

    body = (
        f"Hello {full_name}, you have been invited as a caregiver in Smart Reminder. "
        f"Your verification OTP is {otp_code}. "
        f"Enter this OTP in the app to accept the invitation.{expiry_text}"
    )
    return send_sms_notification(phone_number, body)
