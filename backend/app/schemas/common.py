"""Small schemas shared by the Module 3 (Communication + Community) routers."""
from typing import Generic, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class UserBrief(BaseModel):
    """Public identity of a user: no email or phone number."""
    id: str
    full_name: str
    role: str

    @classmethod
    def from_user(cls, user) -> "UserBrief":
        profile = user.farmer_profile
        return cls(
            id=str(user.id),
            full_name=profile.full_name if profile else user.email.split("@")[0],
            role=user.role.value,
        )


class Page(BaseModel, Generic[T]):
    items: list[T]
    total: int
    page: int
    page_size: int
