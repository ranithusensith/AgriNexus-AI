"""Marketplace wiring: routers mounted, tables created, roles/permissions work."""
from app.core.security import hash_password
from app.models.user import User, UserRole


def _register(client, email, role, phone):
    r = client.post("/users/register", json={
        "email": email, "phone": phone, "password": "securepass123",
        "full_name": "Test User", "role": role,
    })
    assert r.status_code == 201, r.text
    r = client.post("/users/login", json={"email": email, "password": "securepass123"})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def _make_admin(client, db_session):
    db_session.add(User(email="admin@example.com", hashed_password=hash_password("securepass123"),
                        role=UserRole.ADMIN))
    db_session.commit()
    r = client.post("/users/login", json={"email": "admin@example.com", "password": "securepass123"})
    return {"Authorization": f"Bearer {r.json()['access_token']}"}


def test_cannot_self_register_as_admin(client):
    r = client.post("/users/register", json={
        "email": "x@example.com", "password": "securepass123",
        "full_name": "Evil User", "role": "admin"})
    assert r.status_code == 403


def test_marketplace_flow(client, db_session):
    admin = _make_admin(client, db_session)
    farmer = _register(client, "f@example.com", "farmer", "+94770000001")
    buyer = _register(client, "b@example.com", "buyer", "+94770000002")
    supplier = _register(client, "s@example.com", "supplier", "+94770000003")

    # only admin creates categories
    body = {"name": "Vegetables", "slug": "vegetables"}
    assert client.post("/api/categories", json=body, headers=farmer).status_code == 403
    r = client.post("/api/categories", json=body, headers=admin)
    assert r.status_code == 201, r.text
    cat_id = r.json()["id"]

    # buyers cannot sell; farmers and suppliers can
    listing = {"category_id": cat_id, "title": "Fresh carrots", "quantity": "100",
               "unit": "kg", "price": "250"}
    assert client.post("/api/listings", json=listing, headers=buyer).status_code == 403
    r = client.post("/api/listings", json=listing, headers=farmer)
    assert r.status_code == 201, r.text
    listing_id = r.json()["id"]
    sup = {"category_id": cat_id, "listing_type": "supplier_product",
           "supplier_product_type": "seeds", "title": "Seeds", "quantity": "10",
           "unit": "bag", "price": "900"}
    assert client.post("/api/listings", json=sup, headers=supplier).status_code == 201

    # only the owner may edit
    assert client.put(f"/api/listings/{listing_id}", json={"title": "x"}, headers=buyer).status_code == 403
    assert client.put(f"/api/listings/{listing_id}", json={"title": "Carrots"}, headers=farmer).status_code == 200

    # public browse
    assert client.get("/api/products").status_code == 200

    # order lifecycle: buyer orders, only seller accepts
    r = client.post("/api/orders", json={"listing_id": listing_id, "quantity": "5"}, headers=buyer)
    assert r.status_code == 201, r.text
    order_id = r.json()["id"]
    patch = lambda who, st: client.patch(f"/api/orders/{order_id}/status", json={"status": st}, headers=who)
    assert patch(buyer, "accepted").status_code == 403
    assert patch(farmer, "accepted").status_code == 200
    assert patch(farmer, "completed").status_code == 200
    assert client.get("/api/orders/my", headers=buyer).json()
    assert client.get("/api/orders/received", headers=farmer).json()

    # review after completion
    r = client.post("/api/reviews", json={"order_id": order_id, "rating": 5, "comment": "Great"}, headers=buyer)
    assert r.status_code == 201, r.text


def test_module1_routes_still_work(client, auth_headers):
    assert client.get("/health").json()["status"] == "ok"
    assert client.get("/users/me", headers=auth_headers).status_code == 200


def test_seller_profiles_and_bad_ids(client, db_session):
    _register(client, "sp@example.com", "supplier", "+94770000009")
    assert client.get("/api/suppliers/not-a-uuid").status_code == 422
    db_session.rollback()  # tests share one session; real requests each get their own
    assert client.get("/api/suppliers/00000000-0000-0000-0000-000000000000").status_code == 404


def test_supplier_profile_shape(client, db_session):
    _register(client, "sp2@example.com", "supplier", "+94770000010")
    uid = str(db_session.query(User).filter(User.email == "sp2@example.com").first().id)
    r = client.get(f"/api/suppliers/{uid}")
    assert r.status_code == 200, r.text
    assert r.json()["role"] == "supplier" and r.json()["full_name"] == "Test User"
    assert client.get(f"/api/buyers/{uid}").status_code == 200
