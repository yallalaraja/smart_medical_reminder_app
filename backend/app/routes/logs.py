from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import AdherenceLog, Reminder
from ..services import utc_now

logs_bp = Blueprint("logs", __name__)


@logs_bp.post("/logs")
def create_log():
    data = request.get_json() or {}

    required_fields = ["reminder_id", "status"]
    missing = [field for field in required_fields if not data.get(field)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    reminder = db.session.get(Reminder, data["reminder_id"])
    if not reminder:
        return jsonify({"error": "Reminder not found"}), 404

    adherence_log = AdherenceLog(
        reminder_id=data["reminder_id"],
        status=data["status"],
        notes=data.get("notes"),
        action_time=utc_now(),
    )
    db.session.add(adherence_log)

    if data["status"] == "done":
        reminder.last_completed_at = adherence_log.action_time
        reminder.snoozed_until = None
        reminder.last_triggered_at = None
    elif data["status"] == "pending":
        reminder.last_completed_at = None
        reminder.snoozed_until = None
        reminder.last_triggered_at = None
    elif data["status"] == "missed":
        reminder.snoozed_until = None
        reminder.last_triggered_at = None

    db.session.commit()

    return (
        jsonify(
            {
                "id": adherence_log.id,
                "status": adherence_log.status,
                "action_time": adherence_log.action_time.isoformat(),
            }
        ),
        201,
    )


@logs_bp.get("/logs/<int:reminder_id>")
def get_logs(reminder_id: int):
    reminder = db.session.get(Reminder, reminder_id)
    if not reminder:
        return jsonify({"error": "Reminder not found"}), 404

    logs = (
        AdherenceLog.query.filter_by(reminder_id=reminder_id)
        .order_by(AdherenceLog.action_time.desc(), AdherenceLog.id.desc())
        .all()
    )

    return jsonify(
        [
            {
                "id": log.id,
                "status": log.status,
                "action_time": log.action_time.isoformat(),
                "notes": log.notes,
            }
            for log in logs
        ]
    )
