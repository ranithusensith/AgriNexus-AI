"""Module 3 - /api/community."""
import io

from app.tests.module3_helpers import BAD_ID, MISSING_ID, make_admin, register

POST = {"title": "Best fertilizer for paddy?", "body": "Looking for advice for Yala season.",
        "category": "crops"}


def _post(client, headers, **overrides):
    r = client.post("/api/community/posts", json={**POST, **overrides}, headers=headers)
    assert r.status_code == 201, r.text
    return r.json()


def test_create_and_get_post(client, db_session):
    alice, alice_id = register(client, db_session, "alice@example.com", name="Alice Farmer")
    post = _post(client, alice)
    assert post["author"] == {"id": alice_id, "full_name": "Alice Farmer", "role": "farmer"}
    assert post["category"] == "crops" and post["like_count"] == 0 and post["comment_count"] == 0
    assert post["image_url"] is None

    r = client.get(f"/api/community/posts/{post['id']}", headers=alice)
    assert r.status_code == 200 and r.json()["title"] == POST["title"]

    # validation + auth
    assert client.post("/api/community/posts", json={**POST, "title": ""}, headers=alice).status_code == 422
    assert client.post("/api/community/posts", json={**POST, "category": "nope"}, headers=alice).status_code == 422
    assert client.post("/api/community/posts", json=POST).status_code == 401
    assert client.get("/api/community/posts").status_code == 401


def test_list_filter_and_paginate(client, db_session):
    alice, alice_id = register(client, db_session, "alice@example.com")
    bob, _ = register(client, db_session, "bob@example.com", "buyer")
    _post(client, alice, title="Paddy pests", category="pests_diseases")
    _post(client, alice, title="Rain next week", category="weather")
    _post(client, bob, title="Selling tractor", body="Good condition", category="equipment")

    page = client.get("/api/community/posts", params={"page_size": 2}, headers=bob).json()
    assert page["total"] == 3 and len(page["items"]) == 2
    assert page["items"][0]["title"] == "Selling tractor"  # newest first
    page2 = client.get("/api/community/posts", params={"page_size": 2, "page": 2}, headers=bob).json()
    assert len(page2["items"]) == 1

    get = lambda **p: client.get("/api/community/posts", params=p, headers=bob).json()
    assert [p["title"] for p in get(category="weather")["items"]] == ["Rain next week"]
    assert get(author_id=alice_id)["total"] == 2
    assert get(q="TRACTOR")["total"] == 1
    assert get(q="condition")["total"] == 1
    assert client.get("/api/community/posts", params={"author_id": BAD_ID}, headers=bob).status_code == 422
    assert client.get("/api/community/posts", params={"page_size": 500}, headers=bob).status_code == 422


def test_edit_and_delete_permissions(client, db_session):
    alice, _ = register(client, db_session, "alice@example.com")
    bob, _ = register(client, db_session, "bob@example.com")
    admin, _ = make_admin(client, db_session)
    post_id = _post(client, alice)["id"]
    url = f"/api/community/posts/{post_id}"

    assert client.put(url, json={"title": "Hacked"}, headers=bob).status_code == 403
    assert client.put(url, json={"title": "Hacked"}, headers=admin).status_code == 403  # admins moderate, not edit
    r = client.put(url, json={"title": "Edited", "category": "market"}, headers=alice)
    assert r.status_code == 200 and r.json()["title"] == "Edited" and r.json()["category"] == "market"
    assert r.json()["body"] == POST["body"]

    assert client.delete(url, headers=bob).status_code == 403
    assert client.delete(url, headers=alice).status_code == 204
    assert client.get(url, headers=alice).status_code == 404

    # admin may delete anyone's post
    other = _post(client, bob)["id"]
    assert client.delete(f"/api/community/posts/{other}", headers=admin).status_code == 204


def test_likes(client, db_session):
    alice, _ = register(client, db_session, "alice@example.com")
    bob, _ = register(client, db_session, "bob@example.com")
    post_id = _post(client, alice)["id"]
    url = f"/api/community/posts/{post_id}/like"

    assert client.post(url, headers=bob).json() == {"post_id": post_id, "liked": True, "like_count": 1}
    assert client.post(url, headers=bob).json()["like_count"] == 1  # idempotent
    assert client.post(url, headers=alice).json()["like_count"] == 2
    assert client.get(f"/api/community/posts/{post_id}", headers=bob).json()["liked_by_me"] is True
    assert client.delete(url, headers=bob).json() == {"post_id": post_id, "liked": False, "like_count": 1}
    assert client.delete(url, headers=bob).json()["like_count"] == 1
    feed = client.get("/api/community/posts", headers=bob).json()["items"][0]
    assert feed["liked_by_me"] is False and feed["like_count"] == 1


def test_comments(client, db_session):
    alice, _ = register(client, db_session, "alice@example.com")
    bob, bob_id = register(client, db_session, "bob@example.com", name="Bob Buyer")
    carol, _ = register(client, db_session, "carol@example.com")
    admin, _ = make_admin(client, db_session)
    post_id = _post(client, alice)["id"]
    url = f"/api/community/posts/{post_id}/comments"

    r = client.post(url, json={"body": "Try urea"}, headers=bob)
    assert r.status_code == 201, r.text
    comment = r.json()
    assert comment["author"]["full_name"] == "Bob Buyer" and comment["post_id"] == post_id
    client.post(url, json={"body": "Second"}, headers=carol)
    client.post(url, json={"body": "Third"}, headers=alice)
    assert client.post(url, json={"body": ""}, headers=bob).status_code == 422

    page = client.get(url, params={"page_size": 2}, headers=alice).json()
    assert page["total"] == 3 and [c["body"] for c in page["items"]] == ["Try urea", "Second"]  # oldest first
    assert client.get(f"/api/community/posts/{post_id}", headers=alice).json()["comment_count"] == 3

    c_url = f"/api/community/comments/{comment['id']}"
    assert client.put(c_url, json={"body": "x"}, headers=carol).status_code == 403
    assert client.put(c_url, json={"body": "Try organic compost"}, headers=bob).json()["body"] == "Try organic compost"
    assert client.delete(c_url, headers=carol).status_code == 403
    assert client.delete(c_url, headers=alice).status_code == 403  # post author can't delete others' comments
    assert client.delete(c_url, headers=admin).status_code == 204
    assert client.put(c_url, json={"body": "x"}, headers=bob).status_code == 404

    # deleting the post removes its comments and likes
    client.post(f"/api/community/posts/{post_id}/like", headers=bob)
    assert client.delete(f"/api/community/posts/{post_id}", headers=alice).status_code == 204
    assert client.get(url, headers=alice).status_code == 404


def test_post_image_upload(client, db_session, tmp_path, monkeypatch):
    from app.config import settings
    monkeypatch.setattr(settings, "community_upload_dir", str(tmp_path))
    alice, _ = register(client, db_session, "alice@example.com")
    bob, _ = register(client, db_session, "bob@example.com")
    post_id = _post(client, alice)["id"]
    url = f"/api/community/posts/{post_id}/image"
    png = ("leaf.png", io.BytesIO(b"\x89PNG\r\n\x1a\nfake"), "image/png")

    assert client.post(url, files={"file": png}, headers=bob).status_code == 403
    r = client.post(url, files={"file": ("leaf.png", io.BytesIO(b"\x89PNG\r\n\x1a\nfake"), "image/png")},
                    headers=alice)
    assert r.status_code == 200, r.text
    assert r.json()["image_url"].startswith(settings.community_upload_url_prefix + "/")
    assert len(list(tmp_path.iterdir())) == 1
    bad = client.post(url, files={"file": ("a.txt", io.BytesIO(b"hello"), "text/plain")}, headers=alice)
    assert bad.status_code == 400
    assert client.delete(url, headers=alice).json()["image_url"] is None


def test_community_bad_and_missing_ids(client, db_session):
    alice, _ = register(client, db_session, "alice@example.com")
    for method, path in [
        ("get", "/api/community/posts/{}"), ("put", "/api/community/posts/{}"),
        ("delete", "/api/community/posts/{}"), ("post", "/api/community/posts/{}/like"),
        ("get", "/api/community/posts/{}/comments"), ("post", "/api/community/posts/{}/comments"),
        ("put", "/api/community/comments/{}"), ("delete", "/api/community/comments/{}"),
    ]:
        kwargs = {"headers": alice}
        if method in ("post", "put"):
            kwargs["json"] = {"body": "x", "title": "x"}
        assert getattr(client, method)(path.format(BAD_ID), **kwargs).status_code == 422, path
        assert getattr(client, method)(path.format(MISSING_ID), **kwargs).status_code == 404, path
