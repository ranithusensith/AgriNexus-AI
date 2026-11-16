from pydantic import BaseModel


class SellerSummary(BaseModel):
    id: str
    full_name: str
    role: str
    location: str | None = None
    phone_number: str | None = None

    @classmethod
    def from_user(cls, user) -> "SellerSummary":
        """Build from the shared User + its FarmerProfile (name/location live there)."""
        profile = user.farmer_profile
        return cls(
            id=str(user.id),
            full_name=profile.full_name if profile else user.email.split("@")[0],
            role=user.role.value,
            location=(profile.location or profile.district) if profile else None,
            phone_number=user.phone,
        )
