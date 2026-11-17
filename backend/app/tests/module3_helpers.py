"""Shared helpers for the Module 3 (chat / community / issue report) tests."""
import itertools

from app.core.security import hash_password
from app.models.user import User, UserRole

_phone = itertools.count(1)
BAD_ID = "not-a-uuid"
MISSING_ID = "00000000-0000-0000-0000-000000000000"


def _login(client, email):
    r = client.post("/users/login", json={"email": email, "password": "securepass123"})
    assert r.status_code == 200, r.text
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def register(client, db_session, email, role="farmer", name="Test User"):
    """Register + log in. Returns (auth headers, user id as str)."""
    r = client.post("/users/register", json={
        "email": email, "phone": f"+9477{next(_phone):07d}", "password": "securepass123",
        "full_name": name, "role": role,
    })
    assert r.status_code == 201, r.text
    return _login(client, email), r.json()["id"]


def make_admin(client, db_session, email="admin@example.com"):
    user = User(email=email, hashed_password=hash_password("securepass123"), role=UserRole.ADMIN)
    db_session.add(user)
    db_session.commit()
    return _login(client, email), str(user.id)
