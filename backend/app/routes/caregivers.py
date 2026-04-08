from flask import Blueprint, jsonify, request

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

    normalized_phone_number = normalize_phone_number(data["phone_number"])
    if not is_valid_phone_number(normalized_phone_number):
        return jsonify({"error": "phone_number must be a valid mobile number"}), 400

    existing_caregiver = Caregiver.query.filter_by(
        user_id=data["user_id"],
        phone_number=normalized_phone_number,
    ).first()
    if existing_caregiver:
        return jsonify({"error": "This caregiver phone number is already added"}), 409

    otp_code = generate_otp_code()

    caregiver = Caregiver(
        user_id=data["user_id"],
        full_name=data["full_name"].strip(),
        phone_number=normalized_phone_number,
        relationship=data.get("relationship"),
        notification_channel=normalize_notification_channel(
            data.get("notification_channel")
        ),
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

    return jsonify([serialize_caregiver(caregiver) for caregiver in user.caregivers])


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
