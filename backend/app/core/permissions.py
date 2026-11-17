"""
Ownership / role checks used by the Marketplace routers.

Each helper raises HTTP 403 when the check fails. User ids are UUIDs on the
shared `users` table while Marketplace columns hold them as strings, so every
comparison goes through str().

NOTE for Member 2: these rules were inferred from how the routers call them.
Adjust here (one place) if the intended rules differ.
"""
from fastapi import HTTPException, status

from app.models.user import User, UserRole

_SELLER_ROLES = (UserRole.FARMER, UserRole.SUPPLIER, UserRole.ADMIN)


def _forbidden(detail: str) -> HTTPException:
    return HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=detail)


def _is_admin(user: User) -> bool:
    return user.role == UserRole.ADMIN


def assert_can_sell(user: User) -> None:
    """Only farmers, suppliers and admins may create listings."""
    if user.role not in _SELLER_ROLES:
        raise _forbidden("Only farmers and suppliers can create listings")


def assert_owns_listing(listing, user: User) -> None:
    if _is_admin(user):
        return
    if str(listing.seller_id) != str(user.id):
        raise _forbidden("You do not own this listing")


def assert_is_order_seller(order, user: User) -> None:
    if _is_admin(user):
        return
    if str(order.seller_id) != str(user.id):
        raise _forbidden("Only the seller can perform this action")


def assert_is_order_buyer_or_seller(order, user: User) -> None:
    if _is_admin(user):
        return
    if str(user.id) not in (str(order.buyer_id), str(order.seller_id)):
        raise _forbidden("You are not a party to this order")


# ---------------------------------------------------------------------------
# Module 3 (Communication + Community)
# ---------------------------------------------------------------------------

def assert_conversation_participant(conversation, user: User) -> None:
    """Chats are private: only the two participants, not even admins."""
    if str(user.id) not in conversation.participant_ids():
        raise _forbidden("You are not a participant in this conversation")


def assert_is_author(content, user: User) -> None:
    """Editing a post/comment is limited to its author."""
    if str(content.author_id) != str(user.id):
        raise _forbidden("You can only edit your own content")


def assert_author_or_admin(content, user: User) -> None:
    """Deleting a post/comment: its author, or any admin (moderation)."""
    if _is_admin(user):
        return
    if str(content.author_id) != str(user.id):
        raise _forbidden("You can only delete your own content")


def assert_is_admin(user: User) -> None:
    if not _is_admin(user):
        raise _forbidden("Admin access required")


def assert_can_view_report(report, user: User) -> None:
    if _is_admin(user):
        return
    if str(report.reporter_id) != str(user.id):
        raise _forbidden("You can only view your own reports")
