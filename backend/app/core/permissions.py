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
