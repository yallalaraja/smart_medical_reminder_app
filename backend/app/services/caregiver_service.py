import re
import secrets
from datetime import datetime, timedelta

from flask import current_app

from ..models import Caregiver
from .timezone_service import datetime_to_local_iso, utc_now

_ALLOWED_CHANNELS = {"sms", "whatsapp", "both"}
_ALLOWED_STATUSES = {"pending", "accepted", "rejected"}


def normalize_phone_number(phone_number: str | None, default_country_code: str = "+91") -> str | None:
    if not phone_number:
        return None

    cleaned = re.sub(r"[^\d+]", "", phone_number.strip())
    if not cleaned:
        return None

    if cleaned.startswith("+"):
        digits = "+" + re.sub(r"\D", "", cleaned)
    else:
        digits_only = re.sub(r"\D", "", cleaned)
        if len(digits_only) == 10:
            digits = f"{default_country_code}{digits_only}"
        elif len(digits_only) > 10 and not digits_only.startswith(default_country_code.lstrip("+")):
            digits = f"+{digits_only}"
        else:
            digits = f"+{digits_only}" if not digits_only.startswith("+") else digits_only

    normalized_digits = re.sub(r"\D", "", digits)
    if len(normalized_digits) < 10 or len(normalized_digits) > 15:
        return None

    return f"+{normalized_digits}"


def is_valid_phone_number(phone_number: str | None) -> bool:
    return normalize_phone_number(phone_number) is not None


def normalize_notification_channel(channel: str | None, default: str = "sms") -> str:
    normalized = (channel or default).strip().lower()
    if normalized not in _ALLOWED_CHANNELS:
        return default
    return normalized


def normalize_caregiver_status(status: str | None, default: str = "pending") -> str:
    normalized = (status or default).strip().lower()
    if normalized not in _ALLOWED_STATUSES:
        return default
    return normalized


def generate_otp_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def caregiver_otp_expiry_time() -> datetime:
    expiry_minutes = current_app.config.get("CAREGIVER_OTP_EXPIRY_MINUTES", 10)
    return utc_now() + timedelta(minutes=expiry_minutes)


def otp_is_expired(caregiver: Caregiver) -> bool:
    return caregiver.otp_expires_at is None or caregiver.otp_expires_at < utc_now()


def caregiver_can_attempt_verification(caregiver: Caregiver) -> bool:
    max_attempts = current_app.config.get("CAREGIVER_OTP_MAX_ATTEMPTS", 5)
    return caregiver.otp_attempts < max_attempts


def serialize_caregiver(caregiver: Caregiver) -> dict:
    timezone_name = caregiver.user.timezone if caregiver.user else None
    return {
        "id": caregiver.id,
        "user_id": caregiver.user_id,
        "full_name": caregiver.full_name,
        "phone_number": caregiver.phone_number,
        "relationship": caregiver.relationship,
        "notification_channel": caregiver.notification_channel,
        "status": caregiver.status,
        "invited_at": datetime_to_local_iso(caregiver.invited_at, timezone_name),
        "accepted_at": datetime_to_local_iso(caregiver.accepted_at, timezone_name),
        "rejected_at": datetime_to_local_iso(caregiver.rejected_at, timezone_name),
        "otp_expires_at": datetime_to_local_iso(caregiver.otp_expires_at, timezone_name),
    }
