import os

from flask import Flask
from sqlalchemy import inspect

from .config import Config
from .extensions import cors, db
from .models import User
from .routes import register_blueprints


def _refresh_sqlite_schema_if_needed(app: Flask) -> None:
    database_uri = app.config.get("SQLALCHEMY_DATABASE_URI", "")
    if not database_uri.startswith("sqlite:///"):
        return

    inspector = inspect(db.engine)
    table_names = inspector.get_table_names()

    if "reminder" not in table_names or "caregiver" not in table_names or "user" not in table_names:
        db.create_all()
        return

    user_columns = {column["name"] for column in inspector.get_columns("user")}
    reminder_columns = {column["name"] for column in inspector.get_columns("reminder")}
    caregiver_columns = {column["name"] for column in inspector.get_columns("caregiver")}
    expected_user_columns = {
        "id",
        "full_name",
        "phone_number",
        "preferred_language",
        "timezone",
        "created_at",
        "updated_at",
    }
    expected_columns = {
        "id",
        "user_id",
        "title",
        "description",
        "category",
        "scheduled_date",
        "time_of_day",
        "repeat_type",
        "selected_days",
        "is_active",
        "voice_message",
        "alert_audio_path",
        "alert_audio_name",
        "snoozed_until",
        "last_triggered_at",
        "last_completed_at",
        "pending_evaluation_started_at",
        "last_status_notification_at",
        "created_at",
        "updated_at",
    }
    expected_caregiver_columns = {
        "id",
        "user_id",
        "full_name",
        "phone_number",
        "relationship",
        "notification_channel",
        "status",
        "otp_code",
        "otp_expires_at",
        "otp_attempts",
        "invited_at",
        "accepted_at",
        "rejected_at",
        "created_at",
        "updated_at",
    }

    if (
        expected_user_columns.issubset(user_columns)
        and expected_columns.issubset(reminder_columns)
        and expected_caregiver_columns.issubset(caregiver_columns)
    ):
        db.create_all()
        return

    app.logger.warning(
        "SQLite schema is out of date for the local development database. "
        "Recreating tables to match the current models."
    )
    db.drop_all()
    db.create_all()


def _ensure_default_local_user(app: Flask) -> None:
    database_uri = app.config.get("SQLALCHEMY_DATABASE_URI", "")
    if not database_uri.startswith("sqlite:///"):
        return

    default_user = db.session.get(User, 1)
    if default_user is not None:
        return

    app.logger.info("Creating default local user with id=1 for development.")
    db.session.add(
        User(
            id=1,
            full_name="Demo User",
            phone_number="0000000000",
            preferred_language="en",
            timezone=app.config.get("DEFAULT_TIMEZONE", "Asia/Kolkata"),
        )
    )
    db.session.commit()


def create_app(config_class: type[Config] = Config) -> Flask:
    app = Flask(__name__)
    app.config.from_object(config_class)

    os.makedirs(app.config["DATA_DIR"], exist_ok=True)

    db.init_app(app)
    cors.init_app(app)
    register_blueprints(app)

    with app.app_context():
        _refresh_sqlite_schema_if_needed(app)
        _ensure_default_local_user(app)

    return app
