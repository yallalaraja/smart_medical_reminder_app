from datetime import datetime

from ..models import AdherenceLog, Reminder
from .caregiver_service import normalize_notification_channel, serialize_caregiver
from .notification_service import notify_caregiver, with_signature
from .timezone_service import datetime_to_local_iso, format_local_time_for_message

_ALLOWED_LOG_STATUSES = {
    "scheduled",
    "triggered",
    "done",
    "dismissed",
    "snoozed",
    "missed",
    "pending",
}


def parse_time_of_day(time_value: str | None) -> str | None:
    if not time_value:
        return None

    try:
        parsed = datetime.strptime(time_value, "%H:%M")
    except ValueError:
        return None

    return parsed.strftime("%H:%M")


def parse_scheduled_date(date_value: str | None):
    if not date_value:
        return None

    try:
        return datetime.strptime(date_value, "%Y-%m-%d").date()
    except ValueError:
        return None


def normalize_repeat_type(value: str | None) -> str | None:
    if not value:
        return None

    normalized = value.strip().lower()
    allowed = {"once", "daily", "weekdays", "weekends", "custom"}
    if normalized not in allowed:
        return None

    return normalized


def normalize_category(value: str | None) -> str:
    if not value:
        return "personal"
    return value.strip().lower()


def normalize_log_status(value: str | None) -> str | None:
    if not value:
        return None

    normalized = value.strip().lower()
    if normalized not in _ALLOWED_LOG_STATUSES:
        return None

    return normalized


def normalize_selected_days(value: str | list[str] | None, repeat_type: str) -> str | None:
    valid_days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    if repeat_type == "weekdays":
        return "Mon,Tue,Wed,Thu,Fri"
    if repeat_type == "weekends":
        return "Sat,Sun"
    if repeat_type != "custom":
        return None

    if value is None:
        return None

    if isinstance(value, str):
        raw_days = [item.strip() for item in value.split(",") if item.strip()]
    else:
        raw_days = [str(item).strip() for item in value if str(item).strip()]

    normalized_days = [day for day in valid_days if day in raw_days]
    if not normalized_days:
        return None

    return ",".join(normalized_days)


def latest_log_for_reminder(reminder_id: str):
    return (
        AdherenceLog.query.filter_by(reminder_id=reminder_id)
        .order_by(AdherenceLog.action_time.desc(), AdherenceLog.id.desc())
        .first()
    )


def latest_log_for_loaded_reminder(reminder: Reminder) -> AdherenceLog | None:
    if "logs" not in reminder.__dict__:
        return latest_log_for_reminder(reminder.id)

    if not reminder.logs:
        return None

    return max(
        reminder.logs,
        key=lambda log: (log.action_time, log.id),
    )


def latest_log_after(reminder_id: str, started_at) -> AdherenceLog | None:
    return (
        AdherenceLog.query.filter(
            AdherenceLog.reminder_id == reminder_id,
            AdherenceLog.action_time >= started_at,
        )
        .order_by(AdherenceLog.action_time.desc(), AdherenceLog.id.desc())
        .first()
    )


def serialize_reminder(reminder: Reminder):
    latest_log = latest_log_for_loaded_reminder(reminder)
    timezone_name = reminder.user.timezone if reminder.user else None
    latest_status = latest_log.status if latest_log else "pending"
    return {
        "id": reminder.id,
        "user_id": reminder.user_id,
        "title": reminder.title,
        "description": reminder.description,
        "category": reminder.category,
        "scheduled_date": reminder.scheduled_date.isoformat()
        if reminder.scheduled_date
        else None,
        "time_of_day": reminder.time_of_day,
        "repeat_type": reminder.repeat_type,
        "selected_days": reminder.selected_days,
        "voice_message": reminder.voice_message,
        "alert_audio_path": reminder.alert_audio_path,
        "alert_audio_name": reminder.alert_audio_name,
        "is_active": reminder.is_active,
        "user_timezone": timezone_name,
        "snoozed_until": datetime_to_local_iso(reminder.snoozed_until, timezone_name),
        "last_triggered_at": datetime_to_local_iso(reminder.last_triggered_at, timezone_name),
        "last_completed_at": datetime_to_local_iso(reminder.last_completed_at, timezone_name),
        "pending_evaluation_started_at": datetime_to_local_iso(
            reminder.pending_evaluation_started_at,
            timezone_name,
        ),
        "last_status_notification_at": datetime_to_local_iso(
            reminder.last_status_notification_at,
            timezone_name,
        ),
        "latest_status": latest_status,
        "lifecycle_status": derive_lifecycle_status(reminder, latest_status),
        "latest_action_time": datetime_to_local_iso(
            latest_log.action_time if latest_log else None,
            timezone_name,
        ),
    }


def derive_lifecycle_status(reminder: Reminder, latest_status: str | None) -> str:
    normalized_status = normalize_log_status(latest_status) or "pending"

    if normalized_status == "done":
        return "completed"
    if normalized_status in {"dismissed", "missed", "snoozed"}:
        return normalized_status
    if normalized_status == "triggered" or reminder.pending_evaluation_started_at is not None:
        return "triggered"
    return "scheduled"


def _reminder_schedule_text(reminder: Reminder) -> str:
    return format_local_time_for_message(
        scheduled_date=reminder.scheduled_date,
        time_of_day=reminder.time_of_day,
        timezone_name=reminder.user.timezone if reminder.user else None,
    )


def build_completed_notification_message(reminder: Reminder) -> str:
    return with_signature(
        f"Update: The task '{reminder.title}' scheduled at "
        f"{_reminder_schedule_text(reminder)} has been COMPLETED."
    )


def build_missed_notification_message(reminder: Reminder) -> str:
    description_line = f" Notes: {reminder.description}" if reminder.description else ""
    return with_signature(
        f"Alert: The task '{reminder.title}' scheduled at "
        f"{_reminder_schedule_text(reminder)} was MISSED.{description_line} Please check."
    )


def build_dismissed_notification_message(reminder: Reminder) -> str:
    return with_signature(
        f"Update: The task '{reminder.title}' scheduled at "
        f"{_reminder_schedule_text(reminder)} was DISMISSED."
    )


def _notify_accepted_caregivers(
    reminder: Reminder,
    *,
    message: str,
    channel: str | None = None,
) -> dict:
    caregivers = [
        caregiver for caregiver in reminder.user.caregivers if caregiver.status == "accepted"
    ]
    requested_channel = normalize_notification_channel(channel)
    summary = {
        "requested_channel": requested_channel,
        "caregiver_count": len(caregivers),
        "eligible_status": "accepted",
        "notifications": [],
    }

    if not caregivers:
        return summary

    for caregiver in caregivers:
        caregiver_channel = normalize_notification_channel(
            caregiver.notification_channel,
            default=requested_channel,
        )
        effective_channel = requested_channel if channel else caregiver_channel
        results = notify_caregiver(
            caregiver.phone_number,
            message,
            channel=effective_channel,
        )
        summary["notifications"].append(
            {
                "caregiver": serialize_caregiver(caregiver),
                "channel": effective_channel,
                "results": [
                    {
                        "channel": result.channel,
                        "success": result.success,
                        "target": result.target,
                        "sid": result.sid,
                        "error": result.error,
                    }
                    for result in results
                ],
            }
        )

    return summary


def notify_caregivers_for_missed_reminder(
    reminder: Reminder,
    channel: str | None = None,
) -> dict:
    return _notify_accepted_caregivers(
        reminder,
        message=build_missed_notification_message(reminder),
        channel=channel,
    )


def notify_caregivers_for_completed_reminder(
    reminder: Reminder,
    channel: str | None = None,
) -> dict:
    return _notify_accepted_caregivers(
        reminder,
        message=build_completed_notification_message(reminder),
        channel=channel,
    )


def notify_caregivers_for_dismissed_reminder(
    reminder: Reminder,
    channel: str | None = None,
) -> dict:
    return _notify_accepted_caregivers(
        reminder,
        message=build_dismissed_notification_message(reminder),
        channel=channel,
    )


def notify_caregivers(reminder: Reminder) -> dict:
    return notify_caregivers_for_missed_reminder(reminder)


def _legacy_notify_caregivers_unused(reminder):
    from app.services.notification_service import send_alert
    from app.models import Caregiver

    caregivers = Caregiver.query.filter_by(user_id=reminder.user_id).all()
    if not caregivers:
        print(f"No caregivers found for user {reminder.user_id}")
        return

    for caregiver in caregivers:
        try:
            message = (
                "⚠️ ALERT\n\n"
                f"Patient missed reminder:\n"
                f"📝 {reminder.title}\n"
                f"⏰ {reminder.time_of_day}\n\n"
                "Please check immediately."
            )

            final_number = "+91" + caregiver.phone_number.strip()
            print(f"Sending message to: {final_number}")
            print(f"Message content:\n{message}")

            sid = send_alert(caregiver.phone_number, message)
            print(f"Twilio SID: {sid}")
        except Exception as e:
            print(f"Failed for {caregiver.phone_number}: {e}")
