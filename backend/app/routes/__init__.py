from flask import Flask

from .caregivers import caregivers_bp
from .health import health_bp
from .logs import logs_bp
from .reminders import reminders_bp
from .users import users_bp


def register_blueprints(app: Flask) -> None:
    app.register_blueprint(health_bp)
    for blueprint in (users_bp, caregivers_bp, reminders_bp, logs_bp):
        app.register_blueprint(blueprint, url_prefix="/api")
