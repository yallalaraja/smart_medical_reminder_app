from flask import Blueprint, jsonify, request
from flask_jwt_extended import create_access_token

from ..extensions import db
from ..models import User
from ..services import is_valid_phone_number, normalize_phone_number, normalize_timezone

auth_bp = Blueprint("auth", __name__)


@auth_bp.post("/auth/register")
def register():
    data = request.get_json() or {}
    full_name = (data.get("full_name") or "").strip()
    phone_number = normalize_phone_number(data.get("phone_number"))
    password = (data.get("password") or "").strip()

    if not full_name:
        return jsonify({"error": "full_name is required"}), 400
    if not is_valid_phone_number(phone_number):
        return jsonify({"error": "phone_number must be a valid mobile number"}), 400
    if len(password) < 6:
        return jsonify({"error": "password must be at least 6 characters"}), 400

    existing_user = User.query.filter_by(phone_number=phone_number).first()
    if existing_user:
        return jsonify({"error": "A user with this phone number already exists"}), 409

    user = User(
        full_name=full_name,
        phone_number=phone_number,
        preferred_language=data.get("preferred_language", "en"),
        timezone=normalize_timezone(data.get("timezone")),
        password_hash="",
    )
    user.set_password(password)

    db.session.add(user)
    db.session.commit()

    access_token = create_access_token(identity=str(user.id))
    return (
        jsonify(
            {
                "message": "User registered successfully",
                "access_token": access_token,
                "user": {
                    "id": user.id,
                    "full_name": user.full_name,
                    "phone_number": user.phone_number,
                    "preferred_language": user.preferred_language,
                    "timezone": user.timezone,
                },
            }
        ),
        201,
    )


@auth_bp.post("/auth/login")
def login():
    data = request.get_json() or {}
    phone_number = normalize_phone_number(data.get("phone_number"))
    password = (data.get("password") or "").strip()

    if not is_valid_phone_number(phone_number):
        return jsonify({"error": "phone_number must be a valid mobile number"}), 400
    if not password:
        return jsonify({"error": "password is required"}), 400

    user = User.query.filter_by(phone_number=phone_number).first()
    if user is None or not user.check_password(password):
        return jsonify({"error": "Invalid phone number or password"}), 401

    access_token = create_access_token(identity=str(user.id))
    return jsonify(
        {
            "message": "Login successful",
            "access_token": access_token,
            "user": {
                "id": user.id,
                "full_name": user.full_name,
                "phone_number": user.phone_number,
                "preferred_language": user.preferred_language,
                "timezone": user.timezone,
            },
        }
    )
