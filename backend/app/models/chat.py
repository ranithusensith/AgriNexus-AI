"""
Module 3 - Chat: 1-to-1 conversations between two users of the shared
`users` table, optionally linked to a Marketplace listing.

The pair is stored in a canonical order (user_a_id < user_b_id as strings)
so "A talks to B" and "B talks to A" resolve to the same conversation.
"""
import uuid
from datetime import datetime, timezone

from sqlalchemy import Column, DateTime, ForeignKey, Index, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


def _now() -> datetime:
    # Python-side timestamp: several messages can be written in one DB
    # transaction, where now() would give them all the same value.
    return datetime.now(timezone.utc)


class Conversation(Base):
    __tablename__ = "conversations"

    id = Column(String(36), primary_key=True, default=_uuid)
    user_a_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False, index=True)
    user_b_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False, index=True)
    listing_id = Column(
        String(36), ForeignKey("listings.id", ondelete="SET NULL"), nullable=True, index=True
    )
    last_message_at = Column(DateTime(timezone=True), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())

    messages = relationship(
        "Message", back_populates="conversation", cascade="all, delete-orphan", passive_deletes=True
    )

    __table_args__ = (Index("ix_conversations_pair", "user_a_id", "user_b_id"),)

    def participant_ids(self) -> tuple[str, str]:
        return str(self.user_a_id), str(self.user_b_id)

    def other_participant_id(self, user_id) -> str:
        a, b = self.participant_ids()
        return b if str(user_id) == a else a


class Message(Base):
    __tablename__ = "messages"

    id = Column(String(36), primary_key=True, default=_uuid)
    conversation_id = Column(
        String(36), ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False
    )
    sender_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False, index=True)
    body = Column(Text, nullable=False)
    read_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False, default=_now, server_default=func.now())

    conversation = relationship("Conversation", back_populates="messages")

    __table_args__ = (Index("ix_messages_conversation_created", "conversation_id", "created_at"),)
