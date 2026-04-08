from ..extensions import db
from ..models import User


def get_user_or_error(user_id: int | None):
    if not user_id:
        return None, {"error": "user_id is required"}, 400

    user = db.session.get(User, user_id)
    if not user:
        return None, {"error": "User not found"}, 404

    return user, None, None
