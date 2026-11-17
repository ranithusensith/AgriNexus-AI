"""Module 3 - /api/chat."""
from app.tests.module3_helpers import BAD_ID, MISSING_ID, make_admin, register


def _setup(client, db_session):
    buyer, buyer_id = register(client, db_session, "buyer@example.com", "buyer", "Kamal Buyer")
    seller, seller_id = register(client, db_session, "seller@example.com", "farmer", "Sunil Seller")
    outsider, _ = register(client, db_session, "out@example.com", "farmer")
    return buyer, buyer_id, seller, seller_id, outsider


def _listing(client, db_session, seller):
    admin, _ = make_admin(client, db_session)
    cat = client.post("/api/categories", json={"name": "Veg", "slug": "veg"}, headers=admin).json()
    r = client.post("/api/listings", json={"category_id": cat["id"], "title": "Carrots",
                                           "quantity": "10", "unit": "kg", "price": "200"}, headers=seller)
    assert r.status_code == 201, r.text
    return r.json()["id"]


def test_create_or_get_conversation(client, db_session):
    buyer, buyer_id, seller, seller_id, _ = _setup(client, db_session)

    r = client.post("/api/chat/conversations", json={"participant_id": seller_id}, headers=buyer)
    assert r.status_code == 201, r.text
    conv = r.json()
    assert conv["other_user"]["id"] == seller_id
    assert conv["other_user"]["full_name"] == "Sunil Seller"
    assert conv["unread_count"] == 0 and conv["last_message"] is None

    # same pair from the other side -> same conversation, 200
    r = client.post("/api/chat/conversations", json={"participant_id": buyer_id}, headers=seller)
    assert r.status_code == 200
    assert r.json()["id"] == conv["id"]
    assert r.json()["other_user"]["id"] == buyer_id


def test_conversation_linked_to_listing(client, db_session):
    buyer, _, seller, seller_id, _ = _setup(client, db_session)
    listing_id = _listing(client, db_session, seller)

    plain = client.post("/api/chat/conversations", json={"participant_id": seller_id}, headers=buyer).json()
    r = client.post("/api/chat/conversations",
                    json={"participant_id": seller_id, "listing_id": listing_id}, headers=buyer)
    assert r.status_code == 201
    assert r.json()["listing_id"] == listing_id
    assert r.json()["listing_title"] == "Carrots"
    assert r.json()["id"] != plain["id"]

    # deleting the listing keeps the chat, just unlinks it
    assert client.delete(f"/api/listings/{listing_id}", headers=seller).status_code == 204
    db_session.expire_all()
    r = client.get(f"/api/chat/conversations/{r.json()['id']}", headers=buyer)
    assert r.status_code == 200 and r.json()["listing_id"] is None


def test_create_conversation_validation(client, db_session):
    buyer, buyer_id, *_ = _setup(client, db_session)
    post = lambda body: client.post("/api/chat/conversations", json=body, headers=buyer)
    assert post({"participant_id": buyer_id}).status_code == 400
    assert post({"participant_id": MISSING_ID}).status_code == 404
    assert post({"participant_id": BAD_ID}).status_code == 422
    assert post({"participant_id": buyer_id, "listing_id": BAD_ID}).status_code == 422
    assert client.post("/api/chat/conversations", json={"participant_id": buyer_id}).status_code == 401


def test_messages_unread_and_read(client, db_session):
    buyer, buyer_id, seller, seller_id, _ = _setup(client, db_session)
    conv_id = client.post("/api/chat/conversations", json={"participant_id": seller_id}, headers=buyer).json()["id"]
    url = f"/api/chat/conversations/{conv_id}"

    for text in ("Hi", "Are carrots available?", "  Thanks  "):
        r = client.post(f"{url}/messages", json={"body": text}, headers=buyer)
        assert r.status_code == 201, r.text
    assert r.json()["body"] == "Thanks" and r.json()["sender_id"] == buyer_id
    assert client.post(f"{url}/messages", json={"body": ""}, headers=buyer).status_code == 422
    assert client.post(f"{url}/messages", json={"body": "   "}, headers=buyer).status_code == 422

    # seller sees 3 unread; buyer (the sender) sees none
    seller_list = client.get("/api/chat/conversations", headers=seller).json()
    assert len(seller_list) == 1
    assert seller_list[0]["unread_count"] == 3
    assert seller_list[0]["last_message"]["body"] == "Thanks"
    assert client.get("/api/chat/conversations", headers=buyer).json()[0]["unread_count"] == 0
    r = client.get("/api/chat/unread-count", headers=seller).json()
    assert r["unread_count"] == 3 and r["poll_interval_seconds"] > 0

    # pagination, newest first
    r = client.get(f"{url}/messages", params={"page_size": 2}, headers=seller).json()
    assert r["total"] == 3 and [m["body"] for m in r["items"]] == ["Thanks", "Are carrots available?"]
    r = client.get(f"{url}/messages", params={"page_size": 2, "page": 2}, headers=seller).json()
    assert [m["body"] for m in r["items"]] == ["Hi"]

    # mark read: only the recipient's incoming messages
    assert client.post(f"{url}/read", headers=buyer).json()["marked_read"] == 0
    assert client.post(f"{url}/read", headers=seller).json()["marked_read"] == 3
    assert client.get(f"{url}", headers=seller).json()["unread_count"] == 0
    assert client.post(f"{url}/read", headers=seller).json()["marked_read"] == 0

    # reply moves the conversation to the top of the list
    client.post(f"{url}/messages", json={"body": "Yes, 10kg"}, headers=seller)
    assert client.get("/api/chat/unread-count", headers=buyer).json()["unread_count"] == 1


def test_conversations_ordered_by_activity(client, db_session):
    buyer, _, seller, seller_id, _ = _setup(client, db_session)
    _, third_id = register(client, db_session, "third@example.com")
    c1 = client.post("/api/chat/conversations", json={"participant_id": seller_id}, headers=buyer).json()["id"]
    c2 = client.post("/api/chat/conversations", json={"participant_id": third_id}, headers=buyer).json()["id"]
    client.post(f"/api/chat/conversations/{c2}/messages", json={"body": "a"}, headers=buyer)
    client.post(f"/api/chat/conversations/{c1}/messages", json={"body": "b"}, headers=buyer)
    assert [c["id"] for c in client.get("/api/chat/conversations", headers=buyer).json()] == [c1, c2]


def test_only_participants_can_access(client, db_session):
    buyer, _, _, seller_id, outsider = _setup(client, db_session)
    admin, _ = make_admin(client, db_session)
    conv_id = client.post("/api/chat/conversations", json={"participant_id": seller_id}, headers=buyer).json()["id"]
    url = f"/api/chat/conversations/{conv_id}"
    for who in (outsider, admin):
        assert client.get(url, headers=who).status_code == 403
        assert client.get(f"{url}/messages", headers=who).status_code == 403
        assert client.post(f"{url}/messages", json={"body": "x"}, headers=who).status_code == 403
        assert client.post(f"{url}/read", headers=who).status_code == 403
    assert client.get("/api/chat/conversations", headers=outsider).json() == []


def test_chat_bad_and_missing_ids(client, db_session):
    buyer, *_ = _setup(client, db_session)
    for suffix in ("", "/messages"):
        assert client.get(f"/api/chat/conversations/{BAD_ID}{suffix}", headers=buyer).status_code == 422
        assert client.get(f"/api/chat/conversations/{MISSING_ID}{suffix}", headers=buyer).status_code == 404
    assert client.post(f"/api/chat/conversations/{BAD_ID}/read", headers=buyer).status_code == 422
    assert client.post(f"/api/chat/conversations/{MISSING_ID}/messages", json={"body": "x"},
                       headers=buyer).status_code == 404
