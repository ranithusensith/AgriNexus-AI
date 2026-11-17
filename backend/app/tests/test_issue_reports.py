"""Module 3 - /api/issue-reports."""
from app.tests.module3_helpers import BAD_ID, MISSING_ID, make_admin, register


def _content(client, db_session):
    alice, alice_id = register(client, db_session, "alice@example.com", name="Alice Farmer")
    bob, bob_id = register(client, db_session, "bob@example.com", "buyer")
    admin, admin_id = make_admin(client, db_session)
    post = client.post("/api/community/posts", json={"title": "Cheap seeds!!!", "body": "DM me"},
                       headers=alice).json()
    comment = client.post(f"/api/community/posts/{post['id']}/comments", json={"body": "spam link"},
                          headers=alice).json()
    cat = client.post("/api/categories", json={"name": "Veg", "slug": "veg"}, headers=admin).json()
    listing = client.post("/api/listings", json={"category_id": cat["id"], "title": "Fake carrots",
                                                 "quantity": "1", "unit": "kg", "price": "1"}, headers=alice).json()
    return dict(alice=alice, alice_id=alice_id, bob=bob, bob_id=bob_id, admin=admin, admin_id=admin_id,
                post_id=post["id"], comment_id=comment["id"], listing_id=listing["id"])


def _report(client, headers, target_type, target_id, reason="spam", **extra):
    return client.post("/api/issue-reports", json={"target_type": target_type, "target_id": target_id,
                                                   "reason": reason, **extra}, headers=headers)


def test_any_user_can_report_each_target_type(client, db_session):
    c = _content(client, db_session)
    for target_type, target_id in [("post", c["post_id"]), ("comment", c["comment_id"]),
                                   ("user", c["alice_id"]), ("listing", c["listing_id"])]:
        r = _report(client, c["bob"], target_type, target_id, details="Looks like a scam")
        assert r.status_code == 201, r.text
        assert r.json()["status"] == "open" and r.json()["reporter_id"] == c["bob_id"]

    mine = client.get("/api/issue-reports/my", headers=c["bob"]).json()
    assert len(mine) == 4
    assert client.get("/api/issue-reports/my", headers=c["alice"]).json() == []

    # reporter can read their own report; others can't; admin can
    rid = mine[0]["id"]
    assert client.get(f"/api/issue-reports/{rid}", headers=c["bob"]).status_code == 200
    assert client.get(f"/api/issue-reports/{rid}", headers=c["alice"]).status_code == 403
    assert client.get(f"/api/issue-reports/{rid}", headers=c["admin"]).status_code == 200


def test_report_validation(client, db_session):
    c = _content(client, db_session)
    bob = c["bob"]
    assert _report(client, bob, "post", MISSING_ID).status_code == 404
    assert _report(client, bob, "user", MISSING_ID).status_code == 404
    assert _report(client, bob, "post", BAD_ID).status_code == 422
    assert _report(client, bob, "planet", c["post_id"]).status_code == 422
    assert _report(client, bob, "post", c["post_id"], reason="boring").status_code == 422
    assert _report(client, bob, "user", c["bob_id"]).status_code == 400  # self
    assert _report(client, bob, "post", c["post_id"]).status_code == 201
    assert _report(client, bob, "post", c["post_id"]).status_code == 409  # duplicate while open
    assert _report(client, c["alice"], "post", c["post_id"]).status_code == 201  # different reporter ok
    assert client.post("/api/issue-reports", json={"target_type": "post", "target_id": c["post_id"],
                                                   "reason": "spam"}).status_code == 401


def test_admin_list_filter_and_status_workflow(client, db_session):
    c = _content(client, db_session)
    post_report = _report(client, c["bob"], "post", c["post_id"]).json()
    _report(client, c["bob"], "listing", c["listing_id"], reason="scam")
    _report(client, c["bob"], "user", c["alice_id"], reason="harassment")

    # admin only
    assert client.get("/api/issue-reports", headers=c["bob"]).status_code == 403
    page = client.get("/api/issue-reports", headers=c["admin"]).json()
    assert page["total"] == 3
    item = next(i for i in page["items"] if i["id"] == post_report["id"])
    assert item["target_preview"] == "Cheap seeds!!!" and item["reporter"]["id"] == c["bob_id"]
    users = client.get("/api/issue-reports", params={"target_type": "user"}, headers=c["admin"]).json()
    assert users["total"] == 1 and users["items"][0]["target_preview"] == "Alice Farmer"
    assert client.get("/api/issue-reports", params={"status": "bogus"}, headers=c["admin"]).status_code == 422

    url = f"/api/issue-reports/{post_report['id']}/status"
    patch = lambda who, st, **kw: client.patch(url, json={"status": st, **kw}, headers=who)
    assert patch(c["bob"], "reviewed").status_code == 403
    assert patch(c["admin"], "resolved").status_code == 400  # must be reviewed first
    r = patch(c["admin"], "reviewed", admin_note="Checking with author")
    assert r.status_code == 200 and r.json()["status"] == "reviewed"
    assert r.json()["reviewed_by_id"] == c["admin_id"] and r.json()["admin_note"] == "Checking with author"
    assert patch(c["admin"], "open").status_code == 400
    assert patch(c["admin"], "resolved").json()["status"] == "resolved"
    assert patch(c["admin"], "dismissed").status_code == 400  # terminal

    assert client.get("/api/issue-reports", params={"status": "open"}, headers=c["admin"]).json()["total"] == 2
    assert client.get("/api/issue-reports", params={"status": "resolved"},
                      headers=c["admin"]).json()["items"][0]["id"] == post_report["id"]

    # resolved report no longer blocks a new one; deleted content still lists (preview None)
    assert _report(client, c["bob"], "post", c["post_id"]).status_code == 201
    client.delete(f"/api/community/posts/{c['post_id']}", headers=c["admin"])
    items = client.get("/api/issue-reports", params={"target_type": "post"}, headers=c["admin"]).json()["items"]
    assert all(i["target_preview"] is None for i in items)


def test_dismiss_path(client, db_session):
    c = _content(client, db_session)
    rid = _report(client, c["bob"], "comment", c["comment_id"]).json()["id"]
    url = f"/api/issue-reports/{rid}/status"
    client.patch(url, json={"status": "reviewed"}, headers=c["admin"])
    assert client.patch(url, json={"status": "dismissed"}, headers=c["admin"]).json()["status"] == "dismissed"


def test_issue_report_bad_and_missing_ids(client, db_session):
    c = _content(client, db_session)
    assert client.get(f"/api/issue-reports/{BAD_ID}", headers=c["admin"]).status_code == 422
    assert client.get(f"/api/issue-reports/{MISSING_ID}", headers=c["admin"]).status_code == 404
    assert client.patch(f"/api/issue-reports/{BAD_ID}/status", json={"status": "reviewed"},
                        headers=c["admin"]).status_code == 422
    assert client.patch(f"/api/issue-reports/{MISSING_ID}/status", json={"status": "reviewed"},
                        headers=c["admin"]).status_code == 404
