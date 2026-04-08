from flask import Blueprint, jsonify, request

from ..extensions import db
from ..models import User
from ..services import is_valid_phone_number, normalize_phone_number
from ..services.timezone_service import normalize_timezone

users_bp = Blueprint("users", __name__)


@users_bp.post("/users")
def create_user():
    data = request.get_json() or {}
    full_name = data.get("full_name")

    if not full_name:
        return jsonify({"error": "full_name is required"}), 400
    if not data.get("password"):
        return jsonify({"error": "password is required"}), 400

    phone_number = normalize_phone_number(data.get("phone_number"))
    if not is_valid_phone_number(phone_number):
        return jsonify({"error": "phone_number must be a valid mobile number"}), 400
    if User.query.filter_by(phone_number=phone_number).first():
        return jsonify({"error": "A user with this phone number already exists"}), 409

    user = User(
        full_name=full_name,
        phone_number=phone_number,
        preferred_language=data.get("preferred_language", "en"),
        timezone=normalize_timezone(data.get("timezone")),
        password_hash="",
    )
    user.set_password(data["password"])
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


@users_bp.put("/users/<string:user_id>/timezone")
def update_user_timezone(user_id: str):
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
