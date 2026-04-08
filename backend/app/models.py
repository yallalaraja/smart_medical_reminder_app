from datetime import datetime

from .extensions import db


class TimestampMixin:
    created_at = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    updated_at = db.Column(
        db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )


class User(TimestampMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    full_name = db.Column(db.String(120), nullable=False)
    phone_number = db.Column(db.String(20), nullable=True)
    preferred_language = db.Column(db.String(20), default="en", nullable=False)
    timezone = db.Column(db.String(64), default="Asia/Kolkata", nullable=False)

    caregivers = db.relationship("Caregiver", backref="user", lazy=True)
    reminders = db.relationship("Reminder", backref="user", lazy=True)


class Caregiver(TimestampMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    full_name = db.Column(db.String(120), nullable=False)
    phone_number = db.Column(db.String(20), nullable=False)
    relationship = db.Column(db.String(50), nullable=True)
    notification_channel = db.Column(db.String(20), default="sms", nullable=False)
    status = db.Column(db.String(20), default="pending", nullable=False)
    otp_code = db.Column(db.String(6), nullable=True)
    otp_expires_at = db.Column(db.DateTime, nullable=True)
    otp_attempts = db.Column(db.Integer, default=0, nullable=False)
    invited_at = db.Column(db.DateTime, nullable=True)
    accepted_at = db.Column(db.DateTime, nullable=True)
    rejected_at = db.Column(db.DateTime, nullable=True)


class Reminder(TimestampMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey("user.id"), nullable=False)
    title = db.Column(db.String(120), nullable=False)
    description = db.Column(db.String(255), nullable=True)
    category = db.Column(db.String(30), default="personal", nullable=False)
    scheduled_date = db.Column(db.Date, nullable=True)
    time_of_day = db.Column(db.String(5), nullable=False)
    repeat_type = db.Column(db.String(20), default="once", nullable=False)
    selected_days = db.Column(db.String(50), nullable=True)
    is_active = db.Column(db.Boolean, default=True, nullable=False)
    voice_message = db.Column(db.String(255), nullable=True)
    alert_audio_path = db.Column(db.String(500), nullable=True)
    alert_audio_name = db.Column(db.String(255), nullable=True)
    snoozed_until = db.Column(db.DateTime, nullable=True)
    last_triggered_at = db.Column(db.DateTime, nullable=True)
    last_completed_at = db.Column(db.DateTime, nullable=True)
    pending_evaluation_started_at = db.Column(db.DateTime, nullable=True)
    last_status_notification_at = db.Column(db.DateTime, nullable=True)

    logs = db.relationship("AdherenceLog", backref="reminder", lazy=True)


class AdherenceLog(TimestampMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    reminder_id = db.Column(db.Integer, db.ForeignKey("reminder.id"), nullable=False)
    status = db.Column(db.String(20), nullable=False)
    action_time = db.Column(db.DateTime, default=datetime.utcnow, nullable=False)
    notes = db.Column(db.String(255), nullable=True)
