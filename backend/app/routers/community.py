"""
/api/community - posts, comments and likes (Module 3).

Any signed-in user can read, post, comment and like. Authors edit their own
content; authors or admins can delete it.
"""
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, status
from sqlalchemy import func, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.config import settings
from app.core.dependencies import get_current_user
from app.core.permissions import assert_author_or_admin, assert_is_author
from app.database import get_db
from app.models.community import Comment, Post, PostCategory, PostLike
from app.models.user import User
from app.schemas.common import Page
from app.schemas.community import (
    CommentCreate, CommentOut, CommentUpdate, LikeResult, PostCreate, PostOut, PostUpdate,
)
from app.services.image_service import (
    ImageStorageBackend, LocalImageStorage, get_image_storage, validate_and_read_image,
)
from app.services.user_lookup import brief_or_placeholder, load_user_briefs

router = APIRouter(prefix="/api/community", tags=["community"])

MAX_PAGE_SIZE = 50


def _community_image_storage() -> ImageStorageBackend:
    """Reuse the Marketplace storage abstraction, but keep local files in their own folder."""
    if settings.image_storage_backend == "local":
        return LocalImageStorage(settings.community_upload_dir, settings.community_upload_url_prefix)
    return get_image_storage()


def _get_post(db: Session, post_id: uuid.UUID) -> Post:
    post = db.query(Post).filter(Post.id == str(post_id)).first()
    if not post:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Post not found")
    return post


def _get_comment(db: Session, comment_id: uuid.UUID) -> Comment:
    comment = db.query(Comment).filter(Comment.id == str(comment_id)).first()
    if not comment:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Comment not found")
    return comment


def _like_count(db: Session, post_id: str) -> int:
    return db.query(func.count()).select_from(PostLike).filter(PostLike.post_id == post_id).scalar() or 0


def _serialize_posts(db: Session, posts: list[Post], user: User) -> list[PostOut]:
    if not posts:
        return []
    ids = [p.id for p in posts]
    likes = dict(
        db.query(PostLike.post_id, func.count()).filter(PostLike.post_id.in_(ids)).group_by(PostLike.post_id).all()
    )
    comments = dict(
        db.query(Comment.post_id, func.count(Comment.id)).filter(Comment.post_id.in_(ids)).group_by(Comment.post_id).all()
    )
    mine = {
        pid for (pid,) in db.query(PostLike.post_id)
        .filter(PostLike.post_id.in_(ids), PostLike.user_id == str(user.id)).all()
    }
    briefs = load_user_briefs(db, (p.author_id for p in posts))
    return [
        PostOut(
            id=p.id,
            author=brief_or_placeholder(briefs, p.author_id),
            title=p.title,
            body=p.body,
            image_url=p.image_url,
            category=p.category,
            like_count=likes.get(p.id, 0),
            comment_count=comments.get(p.id, 0),
            liked_by_me=p.id in mine,
            created_at=p.created_at,
            updated_at=p.updated_at,
        )
        for p in posts
    ]


def _serialize_comments(db: Session, comments: list[Comment]) -> list[CommentOut]:
    briefs = load_user_briefs(db, (c.author_id for c in comments))
    return [
        CommentOut(
            id=c.id, post_id=c.post_id, author=brief_or_placeholder(briefs, c.author_id),
            body=c.body, created_at=c.created_at, updated_at=c.updated_at,
        )
        for c in comments
    ]


# ---------------- Posts ----------------

@router.get("/posts", response_model=Page[PostOut])
def list_posts(
    category: PostCategory | None = None,
    author_id: uuid.UUID | None = None,
    q: str | None = Query(None, max_length=100, description="Search title and body"),
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=MAX_PAGE_SIZE),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = db.query(Post)
    if category:
        query = query.filter(Post.category == category)
    if author_id:
        query = query.filter(Post.author_id == str(author_id))
    if q and q.strip():
        like = f"%{q.strip()}%"
        query = query.filter(or_(Post.title.ilike(like), Post.body.ilike(like)))
    total = query.count()
    posts = (
        query.order_by(Post.created_at.desc(), Post.id)
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return Page[PostOut](items=_serialize_posts(db, posts, current_user), total=total, page=page, page_size=page_size)


@router.post("/posts", response_model=PostOut, status_code=status.HTTP_201_CREATED)
def create_post(
    payload: PostCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = Post(author_id=str(current_user.id), **payload.model_dump())
    db.add(post)
    db.commit()
    db.refresh(post)
    return _serialize_posts(db, [post], current_user)[0]


@router.get("/posts/{post_id}", response_model=PostOut)
def get_post(
    post_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return _serialize_posts(db, [_get_post(db, post_id)], current_user)[0]


@router.put("/posts/{post_id}", response_model=PostOut)
def update_post(
    post_id: uuid.UUID,
    payload: PostUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = _get_post(db, post_id)
    assert_is_author(post, current_user)
    for field, value in payload.model_dump(exclude_unset=True, exclude_none=True).items():
        setattr(post, field, value)
    db.commit()
    db.refresh(post)
    return _serialize_posts(db, [post], current_user)[0]


@router.delete("/posts/{post_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_post(
    post_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = _get_post(db, post_id)
    assert_author_or_admin(post, current_user)
    db.delete(post)
    db.commit()
    return None


@router.post("/posts/{post_id}/image", response_model=PostOut)
async def upload_post_image(
    post_id: uuid.UUID,
    file: UploadFile,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Attach (or replace) the post's single image. JPEG/PNG/WebP, max 5 MB."""
    post = _get_post(db, post_id)
    assert_is_author(post, current_user)
    contents = await validate_and_read_image(file)
    post.image_url = _community_image_storage().save(file, contents)
    db.commit()
    db.refresh(post)
    return _serialize_posts(db, [post], current_user)[0]


@router.delete("/posts/{post_id}/image", response_model=PostOut)
def remove_post_image(
    post_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = _get_post(db, post_id)
    assert_is_author(post, current_user)
    post.image_url = None
    db.commit()
    db.refresh(post)
    return _serialize_posts(db, [post], current_user)[0]


# ---------------- Likes ----------------

@router.post("/posts/{post_id}/like", response_model=LikeResult)
def like_post(
    post_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Idempotent: liking twice keeps one like."""
    post = _get_post(db, post_id)
    exists = db.query(PostLike).filter(PostLike.post_id == post.id, PostLike.user_id == str(current_user.id)).first()
    if not exists:
        db.add(PostLike(post_id=post.id, user_id=str(current_user.id)))
        try:
            db.commit()
        except IntegrityError:  # a concurrent request liked it first
            db.rollback()
    return LikeResult(post_id=post.id, liked=True, like_count=_like_count(db, post.id))


@router.delete("/posts/{post_id}/like", response_model=LikeResult)
def unlike_post(
    post_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = _get_post(db, post_id)
    db.query(PostLike).filter(PostLike.post_id == post.id, PostLike.user_id == str(current_user.id)).delete()
    db.commit()
    return LikeResult(post_id=post.id, liked=False, like_count=_like_count(db, post.id))


# ---------------- Comments ----------------

@router.get("/posts/{post_id}/comments", response_model=Page[CommentOut])
def list_comments(
    post_id: uuid.UUID,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=MAX_PAGE_SIZE),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Oldest first, so a thread reads top to bottom."""
    post = _get_post(db, post_id)
    query = db.query(Comment).filter(Comment.post_id == post.id)
    total = query.count()
    comments = (
        query.order_by(Comment.created_at.asc(), Comment.id)
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return Page[CommentOut](items=_serialize_comments(db, comments), total=total, page=page, page_size=page_size)


@router.post("/posts/{post_id}/comments", response_model=CommentOut, status_code=status.HTTP_201_CREATED)
def create_comment(
    post_id: uuid.UUID,
    payload: CommentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    post = _get_post(db, post_id)
    comment = Comment(post_id=post.id, author_id=str(current_user.id), body=payload.body)
    db.add(comment)
    db.commit()
    db.refresh(comment)
    return _serialize_comments(db, [comment])[0]


@router.put("/comments/{comment_id}", response_model=CommentOut)
def update_comment(
    comment_id: uuid.UUID,
    payload: CommentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    comment = _get_comment(db, comment_id)
    assert_is_author(comment, current_user)
    comment.body = payload.body
    db.commit()
    db.refresh(comment)
    return _serialize_comments(db, [comment])[0]


@router.delete("/comments/{comment_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_comment(
    comment_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    comment = _get_comment(db, comment_id)
    assert_author_or_admin(comment, current_user)
    db.delete(comment)
    db.commit()
    return None
