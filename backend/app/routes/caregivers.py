from flask import Blueprint, jsonify, request
from sqlalchemy.orm import joinedload

from ..extensions import db
from ..models import Caregiver
from ..services import (
    caregiver_can_attempt_verification,
    caregiver_otp_expiry_time,
    generate_otp_code,
    get_user_or_error,
    is_valid_phone_number,
    normalize_notification_channel,
    normalize_phone_number,
    otp_is_expired,
    serialize_caregiver,
    utc_now,
)
from ..services.notification_service import send_caregiver_invitation

caregivers_bp = Blueprint("caregivers", __name__)


def _validate_caregiver_payload(
    data: dict,
    *,
    user_id: str,
    existing_caregiver_id: str | None = None,
):
    full_name = (data.get("full_name") or "").strip()
    if not full_name:
        return None, {"error": "full_name is required"}, 400

    normalized_phone_number = normalize_phone_number(data.get("phone_number"))
    if not is_valid_phone_number(normalized_phone_number):
        return None, {"error": "phone_number must be a valid mobile number"}, 400

    duplicate_query = Caregiver.query.filter_by(
        user_id=user_id,
        phone_number=normalized_phone_number,
    )
    if existing_caregiver_id:
        duplicate_query = duplicate_query.filter(Caregiver.id != existing_caregiver_id)

    existing_caregiver = duplicate_query.first()
    if existing_caregiver:
        return None, {"error": "This caregiver phone number is already added"}, 409

    caregiver_data = {
        "full_name": full_name,
        "phone_number": normalized_phone_number,
        "relationship": (data.get("relationship") or "").strip() or None,
        "notification_channel": normalize_notification_channel(
            data.get("notification_channel")
        ),
    }
    return caregiver_data, None, None


@caregivers_bp.post("/caregivers")
def create_caregiver():
    data = request.get_json() or {}

    required_fields = ["user_id", "full_name", "phone_number"]
    missing = [field for field in required_fields if not data.get(field)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    _, user_error, status_code = get_user_or_error(data["user_id"])
    if user_error:
        return jsonify(user_error), status_code

    caregiver_data, validation_error, validation_status = _validate_caregiver_payload(
        data,
        user_id=data["user_id"],
    )
    if validation_error:
        return jsonify(validation_error), validation_status

    otp_code = generate_otp_code()

    caregiver = Caregiver(
        user_id=data["user_id"],
        full_name=caregiver_data["full_name"],
        phone_number=caregiver_data["phone_number"],
        relationship=caregiver_data["relationship"],
        notification_channel=caregiver_data["notification_channel"],
        status="pending",
        otp_code=otp_code,
        otp_expires_at=caregiver_otp_expiry_time(),
        otp_attempts=0,
        invited_at=utc_now(),
    )
    db.session.add(caregiver)
    db.session.commit()

    invitation_result = send_caregiver_invitation(
        caregiver.phone_number,
        caregiver.full_name,
        otp_code,
        caregiver.otp_expires_at,
        caregiver.user.timezone,
    )

    return (
        jsonify(
            {
                "message": "Caregiver invitation created",
                "caregiver": serialize_caregiver(caregiver),
                "invitation": {
                    "success": invitation_result.success,
                    "sid": invitation_result.sid,
                    "error": invitation_result.error,
                },
            }
        ),
        201,
    )


@caregivers_bp.get("/users/<string:user_id>/caregivers")
def list_caregivers(user_id: str):
    user, user_error, status_code = get_user_or_error(user_id)
    if user_error:
        return jsonify(user_error), status_code

    caregivers = (
        Caregiver.query.options(joinedload(Caregiver.user))
        .filter_by(user_id=user.id)
        .order_by(Caregiver.created_at.desc())
        .all()
    )
    return jsonify([serialize_caregiver(caregiver) for caregiver in caregivers])


@caregivers_bp.put("/caregivers/<string:caregiver_id>")
def update_caregiver(caregiver_id: str):
    caregiver = Caregiver.query.get_or_404(caregiver_id)
    data = request.get_json() or {}
    existing_phone_number = caregiver.phone_number

    caregiver_data, validation_error, validation_status = _validate_caregiver_payload(
        data,
        user_id=caregiver.user_id,
        existing_caregiver_id=caregiver.id,
    )
    if validation_error:
        return jsonify(validation_error), validation_status

    caregiver.full_name = caregiver_data["full_name"]
    caregiver.phone_number = caregiver_data["phone_number"]
    caregiver.relationship = caregiver_data["relationship"]
    caregiver.notification_channel = caregiver_data["notification_channel"]

    phone_number_changed = caregiver.phone_number != existing_phone_number
    should_restart_verification = caregiver.status != "accepted" or phone_number_changed

    if should_restart_verification:
        caregiver.status = "pending"
        caregiver.accepted_at = None
        caregiver.rejected_at = None
        caregiver.otp_code = generate_otp_code()
        caregiver.otp_expires_at = caregiver_otp_expiry_time()
        caregiver.otp_attempts = 0
        caregiver.invited_at = utc_now()
        db.session.commit()

        invitation_result = send_caregiver_invitation(
            caregiver.phone_number,
            caregiver.full_name,
            caregiver.otp_code,
            caregiver.otp_expires_at,
            caregiver.user.timezone,
        )

        message = (
            "Caregiver updated and phone number verification restarted"
            if phone_number_changed
            else "Caregiver updated and verification restarted"
        )
        return jsonify(
            {
                "message": message,
                "caregiver": serialize_caregiver(caregiver),
                "invitation": {
                    "success": invitation_result.success,
                    "sid": invitation_result.sid,
                    "error": invitation_result.error,
                },
            }
        )

    db.session.commit()
    return jsonify(
        {
            "message": "Caregiver updated successfully",
            "caregiver": serialize_caregiver(caregiver),
        }
    )


@caregivers_bp.post("/caregivers/<string:caregiver_id>/resend-invitation")
def resend_caregiver_invitation(caregiver_id: str):
    caregiver = Caregiver.query.get_or_404(caregiver_id)
    if caregiver.status == "accepted":
        return jsonify({"error": "Caregiver is already verified"}), 400

    caregiver.otp_code = generate_otp_code()
    caregiver.otp_expires_at = caregiver_otp_expiry_time()
    caregiver.otp_attempts = 0
    caregiver.invited_at = utc_now()
    caregiver.status = "pending"
    caregiver.rejected_at = None
    db.session.commit()

    invitation_result = send_caregiver_invitation(
        caregiver.phone_number,
        caregiver.full_name,
        caregiver.otp_code,
        caregiver.otp_expires_at,
        caregiver.user.timezone,
    )
    return jsonify(
        {
            "message": "Invitation resent",
            "caregiver": serialize_caregiver(caregiver),
            "invitation": {
                "success": invitation_result.success,
                "sid": invitation_result.sid,
                "error": invitation_result.error,
            },
        }
    )


@caregivers_bp.post("/caregivers/verify-otp")
def verify_caregiver_otp():
    data = request.get_json() or {}
    caregiver_id = data.get("caregiver_id")
    otp_code = str(data.get("otp_code") or "").strip()

    if not caregiver_id or not otp_code:
        return jsonify({"error": "caregiver_id and otp_code are required"}), 400

    caregiver = Caregiver.query.get_or_404(caregiver_id)

    if caregiver.status == "accepted":
        return jsonify({"message": "Caregiver already verified", "caregiver": serialize_caregiver(caregiver)})

    if caregiver.status == "rejected":
        return jsonify({"error": "This caregiver invitation was rejected"}), 400

    if not caregiver_can_attempt_verification(caregiver):
        return jsonify({"error": "Maximum OTP verification attempts reached"}), 400

    if otp_is_expired(caregiver):
        return jsonify({"error": "OTP expired. Please resend the invitation"}), 400

    if caregiver.otp_code != otp_code:
        caregiver.otp_attempts += 1
        db.session.commit()
        return jsonify({"error": "Invalid OTP"}), 400

    caregiver.status = "accepted"
    caregiver.accepted_at = utc_now()
    caregiver.rejected_at = None
    caregiver.otp_code = None
    caregiver.otp_expires_at = None
    caregiver.otp_attempts = 0
    db.session.commit()

    return jsonify(
        {
            "message": "Caregiver verified successfully",
            "caregiver": serialize_caregiver(caregiver),
        }
    )


@caregivers_bp.post("/caregivers/<string:caregiver_id>/reject")
def reject_caregiver_invitation(caregiver_id: str):
    caregiver = Caregiver.query.get_or_404(caregiver_id)
    caregiver.status = "rejected"
    caregiver.rejected_at = utc_now()
    caregiver.otp_code = None
    caregiver.otp_expires_at = None
    caregiver.otp_attempts = 0
    db.session.commit()

    return jsonify(
        {
            "message": "Caregiver invitation rejected",
            "caregiver": serialize_caregiver(caregiver),
        }
    )


@caregivers_bp.delete("/caregivers/<string:caregiver_id>")
def delete_caregiver(caregiver_id: str):
    caregiver = Caregiver.query.get_or_404(caregiver_id)
    full_name = caregiver.full_name
    db.session.delete(caregiver)
    db.session.commit()

    return jsonify(
        {
            "message": f"Caregiver {full_name} deleted successfully",
        }
    )
