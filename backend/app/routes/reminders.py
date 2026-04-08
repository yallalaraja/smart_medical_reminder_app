from datetime import datetime, timedelta

from flask import Blueprint, current_app, jsonify, request

from ..extensions import db
from ..models import AdherenceLog, Reminder, User
from ..services import (
    get_user_or_error,
    normalize_category,
    normalize_repeat_type,
    normalize_selected_days,
    notify_caregivers_for_missed_reminder,
    parse_scheduled_date,
    parse_time_of_day,
    schedule_reminder_final_status_evaluation,
    serialize_caregiver,
    serialize_reminder,
    utc_now,
)

reminders_bp = Blueprint("reminders", __name__)


@reminders_bp.get("/reminders")
def list_reminders():
    user_id = request.args.get("user_id")

    query = Reminder.query
    if user_id:
        user, user_error, status_code = get_user_or_error(user_id)
        if user_error:
            return jsonify(user_error), status_code
        query = query.filter_by(user_id=user.id)

    reminders = query.order_by(Reminder.created_at.desc()).all()
    return jsonify([serialize_reminder(reminder) for reminder in reminders])


@reminders_bp.post("/reminders")
def create_reminder():
    data = request.get_json() or {}

    required_fields = ["user_id", "title", "time_of_day", "repeat_type"]
    missing = [field for field in required_fields if not data.get(field)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    _, user_error, status_code = get_user_or_error(data["user_id"])
    if user_error:
        return jsonify(user_error), status_code

    normalized_time = parse_time_of_day(data.get("time_of_day"))
    if not normalized_time:
        return jsonify({"error": "time_of_day must be in HH:MM format"}), 400

    repeat_type = normalize_repeat_type(data.get("repeat_type"))
    if not repeat_type:
        return (
            jsonify(
                {
                    "error": "repeat_type must be once, daily, weekdays, weekends, or custom"
                }
            ),
            400,
        )

    selected_days = normalize_selected_days(data.get("selected_days"), repeat_type)
    if repeat_type == "custom" and not selected_days:
        return jsonify({"error": "selected_days is required for custom repeat type"}), 400

    scheduled_date = parse_scheduled_date(data.get("scheduled_date"))
    if repeat_type == "once" and not scheduled_date:
        return jsonify({"error": "scheduled_date is required for one-time reminders"}), 400
    if data.get("scheduled_date") and not scheduled_date:
        return jsonify({"error": "scheduled_date must be in YYYY-MM-DD format"}), 400

    reminder = Reminder(
        user_id=data["user_id"],
        title=data["title"].strip(),
        description=data.get("description"),
        category=normalize_category(data.get("category")),
        scheduled_date=scheduled_date,
        time_of_day=normalized_time,
        repeat_type=repeat_type,
        selected_days=selected_days,
        is_active=data.get("is_active", True),
        voice_message=data.get("voice_message") or f"It's time for {data['title'].strip()}",
        alert_audio_path=data.get("alert_audio_path"),
        alert_audio_name=data.get("alert_audio_name"),
    )
    db.session.add(reminder)
    db.session.commit()

    return jsonify(serialize_reminder(reminder)), 201


@reminders_bp.get("/reminders/<string:reminder_id>")
def get_reminder(reminder_id: str):
    reminder = Reminder.query.get_or_404(reminder_id)
    return jsonify(serialize_reminder(reminder))


@reminders_bp.put("/reminders/<string:reminder_id>")
def update_reminder(reminder_id: str):
    reminder = Reminder.query.get_or_404(reminder_id)
    data = request.get_json() or {}
    schedule_updated = False

    if "title" in data and data["title"]:
        reminder.title = data["title"].strip()
    if "description" in data:
        reminder.description = data.get("description")
    if "category" in data:
        reminder.category = normalize_category(data.get("category"))
    if "scheduled_date" in data:
        scheduled_date = parse_scheduled_date(data.get("scheduled_date"))
        if data.get("scheduled_date") and not scheduled_date:
            return jsonify({"error": "scheduled_date must be in YYYY-MM-DD format"}), 400
        reminder.scheduled_date = scheduled_date
        schedule_updated = True
    if "time_of_day" in data:
        normalized_time = parse_time_of_day(data.get("time_of_day"))
        if not normalized_time:
            return jsonify({"error": "time_of_day must be in HH:MM format"}), 400
        reminder.time_of_day = normalized_time
        schedule_updated = True
    if "repeat_type" in data:
        repeat_type = normalize_repeat_type(data.get("repeat_type"))
        if not repeat_type:
            return (
                jsonify(
                    {
                        "error": "repeat_type must be once, daily, weekdays, weekends, or custom"
                    }
                ),
                400,
            )
        reminder.repeat_type = repeat_type
        selected_days = normalize_selected_days(data.get("selected_days"), repeat_type)
        if repeat_type == "custom" and not selected_days:
            return jsonify({"error": "selected_days is required for custom repeat type"}), 400
        reminder.selected_days = selected_days
        schedule_updated = True
        if repeat_type == "once" and reminder.scheduled_date is None:
            return jsonify({"error": "scheduled_date is required for one-time reminders"}), 400
    elif "selected_days" in data:
        selected_days = normalize_selected_days(
            data.get("selected_days"), reminder.repeat_type
        )
        if reminder.repeat_type == "custom" and not selected_days:
            return jsonify({"error": "selected_days is required for custom repeat type"}), 400
        reminder.selected_days = selected_days
        schedule_updated = True
    if "voice_message" in data:
        reminder.voice_message = data.get("voice_message")
    if "alert_audio_path" in data:
        reminder.alert_audio_path = data.get("alert_audio_path")
    if "alert_audio_name" in data:
        reminder.alert_audio_name = data.get("alert_audio_name")
    if "is_active" in data:
        reminder.is_active = bool(data["is_active"])
        schedule_updated = True

    if schedule_updated:
        reminder.last_triggered_at = None

    db.session.commit()
    return jsonify(serialize_reminder(reminder))


@reminders_bp.put("/reminders/<string:reminder_id>/snooze")
def snooze_reminder(reminder_id: str):
    reminder = Reminder.query.get_or_404(reminder_id)
    data = request.get_json() or {}
    minutes = int(data.get("minutes", 10))

    if minutes < 1 or minutes > 240:
        return jsonify({"error": "minutes must be between 1 and 240"}), 400

    reminder.snoozed_until = utc_now() + timedelta(minutes=minutes)
    reminder.last_triggered_at = None

    db.session.add(
        AdherenceLog(
            reminder_id=reminder.id,
            status="snoozed",
            notes=f"Snoozed for {minutes} minutes",
        )
    )
    db.session.commit()

    return jsonify(serialize_reminder(reminder))


@reminders_bp.put("/reminders/<string:reminder_id>/trigger")
def trigger_reminder(reminder_id: str):
    reminder = Reminder.query.get_or_404(reminder_id)
    reminder.last_triggered_at = utc_now()
    reminder.pending_evaluation_started_at = reminder.last_triggered_at

    db.session.add(
        AdherenceLog(
            reminder_id=reminder.id,
            status="triggered",
            notes="Reminder reached due time in the app",
        )
    )
    db.session.commit()
    schedule_reminder_final_status_evaluation(
        current_app._get_current_object(),
        reminder.id,
        reminder.pending_evaluation_started_at,
    )

    return jsonify(serialize_reminder(reminder))


@reminders_bp.post("/reminders/<string:reminder_id>/missed")
def mark_missed(reminder_id: str):
    reminder = Reminder.query.get_or_404(reminder_id)
    data = request.get_json(silent=True) or {}

    adherence_log = AdherenceLog(
        reminder_id=reminder.id,
        status="missed",
        notes=data.get("notes") or "User did not respond to the reminder",
    )
    db.session.add(adherence_log)
    reminder.snoozed_until = None
    reminder.last_triggered_at = None
    db.session.flush()

    notification_summary = notify_caregivers_for_missed_reminder(
        reminder,
        channel=data.get("channel"),
    )
    reminder.last_status_notification_at = utc_now()
    reminder.pending_evaluation_started_at = None
    db.session.commit()

    return jsonify(
        {
            "message": "Reminder marked as missed",
            "reminder": serialize_reminder(reminder),
            "log": {
                "id": adherence_log.id,
                "status": adherence_log.status,
                "action_time": adherence_log.action_time.isoformat(),
                "notes": adherence_log.notes,
            },
            "notifications": notification_summary,
        }
    )


@reminders_bp.delete("/reminders/<string:reminder_id>")
def delete_reminder(reminder_id: str):
    reminder = Reminder.query.get_or_404(reminder_id)

    AdherenceLog.query.filter_by(reminder_id=reminder.id).delete()
    db.session.delete(reminder)
    db.session.commit()
    return jsonify({"message": "Reminder deleted successfully"})


@reminders_bp.get("/dashboard/<string:user_id>")
def get_dashboard(user_id: str):
    user = User.query.get_or_404(user_id)

    reminders = [serialize_reminder(reminder) for reminder in user.reminders]

    caregivers = [serialize_caregiver(caregiver) for caregiver in user.caregivers]

    return jsonify(
        {
            "user": {
                "id": user.id,
                "full_name": user.full_name,
                "phone_number": user.phone_number,
                "preferred_language": user.preferred_language,
                "timezone": user.timezone,
            },
            "reminders": reminders,
            "caregivers": caregivers,
        }
    )
