from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from flask import current_app

_UTC = ZoneInfo("UTC")


def utc_now() -> datetime:
    return datetime.utcnow()


def normalize_timezone(value: str | None) -> str:
    fallback = current_app.config.get("DEFAULT_TIMEZONE", "Asia/Kolkata")
    candidate = (value or fallback).strip()
    try:
        ZoneInfo(candidate)
        return candidate
    except ZoneInfoNotFoundError:
        return fallback


def to_user_timezone(value: datetime | None, timezone_name: str | None) -> datetime | None:
    if value is None:
        return None

    aware_utc = value.replace(tzinfo=_UTC)
    return aware_utc.astimezone(ZoneInfo(normalize_timezone(timezone_name)))


def datetime_to_local_iso(value: datetime | None, timezone_name: str | None) -> str | None:
    localized = to_user_timezone(value, timezone_name)
    return localized.isoformat() if localized is not None else None


def format_local_time_for_message(
    *,
    scheduled_date,
    time_of_day: str,
    timezone_name: str | None,
) -> str:
    timezone_label = normalize_timezone(timezone_name)
    if scheduled_date:
        return f"{scheduled_date.isoformat()} {time_of_day} ({timezone_label})"
    return f"{time_of_day} ({timezone_label})"
