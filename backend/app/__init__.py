import os
from urllib.parse import urlsplit, urlunsplit

from flask import Flask, jsonify
from sqlalchemy import inspect

from .config import Config
from .extensions import cors, db, jwt
from .models import User
from .routes import register_blueprints


def _mask_database_uri(database_uri: str) -> str:
    if not database_uri:
        return "<missing>"
    if database_uri.startswith("sqlite:///"):
        return database_uri

    parts = urlsplit(database_uri)
    if "@" not in parts.netloc:
        return database_uri

    credentials, host = parts.netloc.rsplit("@", 1)
    username = credentials.split(":", 1)[0] if credentials else ""
    masked_netloc = f"{username}:***@{host}" if username else host
    return urlunsplit((parts.scheme, masked_netloc, parts.path, parts.query, parts.fragment))


def _log_database_startup(app: Flask, stage: str) -> None:
    database_uri = app.config.get("SQLALCHEMY_DATABASE_URI", "")
    app.logger.info("Database stage: %s", stage)
    app.logger.info("Database URI: %s", _mask_database_uri(database_uri))
    app.logger.info("Database dialect: %s", db.engine.dialect.name)

    inspector = inspect(db.engine)
    table_names = inspector.get_table_names()
    app.logger.info("Available tables: %s", ", ".join(table_names) if table_names else "<none>")


def _ensure_demo_user(app: Flask) -> None:
    if not app.config.get("CREATE_DEMO_USER", True):
        return

    demo_user_id = app.config.get("DEMO_USER_ID")
    existing_user = db.session.get(User, demo_user_id)
    if existing_user is not None:
        app.logger.info("Demo user already exists with id=%s", demo_user_id)
        return

    demo_user = User(
        id=demo_user_id,
        full_name=app.config.get("DEMO_USER_NAME", "Demo User"),
        phone_number=app.config.get("DEMO_USER_PHONE", "9999999999"),
        preferred_language="en",
        timezone=app.config.get("DEFAULT_TIMEZONE", "Asia/Kolkata"),
        password_hash="",
    )
    demo_user.set_password(app.config.get("DEMO_USER_PASSWORD", "password123"))
    db.session.add(demo_user)
    db.session.commit()
    app.logger.info(
        "Created demo user with id=%s and phone=%s",
        demo_user.id,
        demo_user.phone_number,
    )


def create_app(config_class: type[Config] = Config) -> Flask:
    app = Flask(__name__)
    app.config.from_object(config_class)

    os.makedirs(app.config["DATA_DIR"], exist_ok=True)

    db.init_app(app)
    cors.init_app(app)
    jwt.init_app(app)
    register_blueprints(app)

    @app.errorhandler(400)
    def bad_request(error):
        return jsonify({"error": "Bad request"}), 400

    @app.errorhandler(404)
    def not_found(error):
        return jsonify({"error": "Resource not found"}), 404

    @app.errorhandler(500)
    def internal_error(error):
        return jsonify({"error": "Internal server error"}), 500

    with app.app_context():
        _log_database_startup(app, "before-create-all")
        app.logger.info("Running db.create_all() for PostgreSQL database.")
        db.create_all()
        _ensure_demo_user(app)
        _log_database_startup(app, "after-create-all")

    return app
