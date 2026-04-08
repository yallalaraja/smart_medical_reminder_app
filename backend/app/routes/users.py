from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import User
from ..services.timezone_service import normalize_timezone

users_bp = Blueprint("users", __name__)


@users_bp.post("/users")
def create_user():
    data = request.get_json() or {}
    full_name = data.get("full_name")

    if not full_name:
        return jsonify({"error": "full_name is required"}), 400

    user = User(
        full_name=full_name,
        phone_number=data.get("phone_number"),
        preferred_language=data.get("preferred_language", "en"),
        timezone=normalize_timezone(data.get("timezone")),
    )
    db.session.add(user)
    db.session.commit()

    return (
        jsonify(
            {
                "id": user.id,
                "full_name": user.full_name,
                "phone_number": user.phone_number,
                "preferred_language": user.preferred_language,
                "timezone": user.timezone,
            }
        ),
        201,
    )


@users_bp.put("/users/<int:user_id>/timezone")
def update_user_timezone(user_id: int):
    user = User.query.get_or_404(user_id)
    data = request.get_json() or {}
    timezone_name = data.get("timezone")
    if not timezone_name:
        return jsonify({"error": "timezone is required"}), 400

    user.timezone = normalize_timezone(timezone_name)
    db.session.commit()

    return jsonify(
        {
            "message": "User timezone updated",
            "user": {
                "id": user.id,
                "full_name": user.full_name,
                "timezone": user.timezone,
            },
        }
    )
