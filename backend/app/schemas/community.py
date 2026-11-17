from datetime import datetime

from pydantic import BaseModel, Field

from app.models.community import PostCategory
from app.schemas.common import UserBrief


class PostCreate(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    body: str = Field(min_length=1, max_length=10000)
    category: PostCategory = PostCategory.general


class PostUpdate(BaseModel):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    body: str | None = Field(default=None, min_length=1, max_length=10000)
    category: PostCategory | None = None


class PostOut(BaseModel):
    id: str
    author: UserBrief
    title: str
    body: str
    image_url: str | None
    category: PostCategory
    like_count: int = 0
    comment_count: int = 0
    liked_by_me: bool = False
    created_at: datetime
    updated_at: datetime | None


class CommentCreate(BaseModel):
    body: str = Field(min_length=1, max_length=4000)


class CommentUpdate(CommentCreate):
    pass


class CommentOut(BaseModel):
    id: str
    post_id: str
    author: UserBrief
    body: str
    created_at: datetime
    updated_at: datetime | None


class LikeResult(BaseModel):
    post_id: str
    liked: bool
    like_count: int


