"""Batch-load public user summaries for Module 3 responses (one query per page)."""
import uuid
from collections.abc import Iterable

from sqlalchemy.orm import Session, selectinload

from app.models.user import User
from app.schemas.common import UserBrief

_UNKNOWN = "Unknown user"


def load_user_briefs(db: Session, user_ids: Iterable) -> dict[str, UserBrief]:
    ids = {str(u) for u in user_ids if u is not None}
    if not ids:
        return {}
    users = (
        db.query(User)
        .options(selectinload(User.farmer_profile))
        .filter(User.id.in_([uuid.UUID(i) for i in ids]))
        .all()
    )
    return {str(u.id): UserBrief.from_user(u) for u in users}


def brief_or_placeholder(briefs: dict[str, UserBrief], user_id) -> UserBrief:
    return briefs.get(str(user_id)) or UserBrief(id=str(user_id), full_name=_UNKNOWN, role="unknown")
