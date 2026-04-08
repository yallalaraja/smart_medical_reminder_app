from flask import Blueprint, jsonify

health_bp = Blueprint("health", __name__)


@health_bp.get("/")
def root():
    return jsonify(
        {
            "app": "smart-reminder-api",
            "status": "ok",
            "message": "API is running",
            "api_base": "/api",
            "sample_endpoints": [
                "/api/reminders",
                "/api/dashboard/<user_id>",
                "/api/users/<user_id>/caregivers",
            ],
        }
    )
