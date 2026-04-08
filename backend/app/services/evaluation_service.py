import threading
import time

from ..extensions import db
from ..models import AdherenceLog, Reminder
from .reminder_service import (
    latest_log_after,
    notify_caregivers_for_completed_reminder,
    notify_caregivers_for_missed_reminder,
)
from .timezone_service import utc_now


def schedule_reminder_final_status_evaluation(
    app,
    reminder_id: str,
    started_at,
) -> None:
    delay_seconds = app.config.get("REMINDER_FINAL_STATUS_DELAY_SECONDS", 60)

    worker = threading.Thread(
        target=_evaluate_reminder_after_delay,
        args=(app, reminder_id, started_at, delay_seconds),
        daemon=True,
    )
    worker.start()


def _evaluate_reminder_after_delay(
    app,
    reminder_id: str,
    started_at,
    delay_seconds: int,
) -> None:
    time.sleep(delay_seconds)

    with app.app_context():
        reminder = db.session.get(Reminder, reminder_id)
        if reminder is None:
            return

        if reminder.pending_evaluation_started_at != started_at:
            return

        latest_log = latest_log_after(reminder.id, started_at)
        final_status = "missed"

        if latest_log is not None:
            if latest_log.status == "done":
                final_status = "completed"
            elif latest_log.status in {"snoozed", "pending"}:
                reminder.pending_evaluation_started_at = None
                db.session.commit()
                return
            elif latest_log.status == "missed":
                final_status = "missed"

        if final_status == "missed" and (
            latest_log is None or latest_log.status not in {"missed", "done"}
        ):
            db.session.add(
                AdherenceLog(
                    reminder_id=reminder.id,
                    status="missed",
                    notes="Automatically marked missed after delayed evaluation",
                )
            )

        reminder.last_status_notification_at = utc_now()
        reminder.pending_evaluation_started_at = None
        db.session.commit()

        if final_status == "completed":
            notify_caregivers_for_completed_reminder(reminder)
        elif final_status == "missed":
            notify_caregivers_for_missed_reminder(reminder)
