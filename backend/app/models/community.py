"""
Module 3 - Community: posts, comments and likes. Authors are rows in the
shared `users` table.
"""
import enum
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, Enum, ForeignKey, Index, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    return datetime.now(timezone.utc)


class PostCategory(str, enum.Enum):
    general = "general"
    crops = "crops"
    pests_diseases = "pests_diseases"
    weather = "weather"
    market = "market"
    equipment = "equipment"
    other = "other"


class Post(Base):
    __tablename__ = "community_posts"

    id = Column(String(36), primary_key=True, default=_uuid)
    author_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False, index=True)
    title = Column(String(200), nullable=False)
    body = Column(Text, nullable=False)
    image_url = Column(String(500), nullable=True)
    category = Column(Enum(PostCategory), nullable=False, default=PostCategory.general, index=True)

    created_at = Column(DateTime(timezone=True), nullable=False, default=_now, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    comments = relationship(
        "Comment", back_populates="post", cascade="all, delete-orphan", passive_deletes=True
    )
    likes = relationship(
        "PostLike", back_populates="post", cascade="all, delete-orphan", passive_deletes=True
    )


class Comment(Base):
    __tablename__ = "community_comments"

    id = Column(String(36), primary_key=True, default=_uuid)
    post_id = Column(
        String(36), ForeignKey("community_posts.id", ondelete="CASCADE"), nullable=False
    )
    author_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False, index=True)
    body = Column(Text, nullable=False)

    created_at = Column(DateTime(timezone=True), nullable=False, default=_now, server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    post = relationship("Post", back_populates="comments")

    __table_args__ = (Index("ix_community_comments_post_created", "post_id", "created_at"),)


class PostLike(Base):
    __tablename__ = "community_post_likes"

    post_id = Column(
        String(36), ForeignKey("community_posts.id", ondelete="CASCADE"), primary_key=True
    )
    user_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), primary_key=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    post = relationship("Post", back_populates="likes")
