import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.common import UserBrief


class ConversationCreate(BaseModel):
    participant_id: uuid.UUID
    listing_id: uuid.UUID | None = None


class MessageCreate(BaseModel):
    body: str = Field(min_length=1, max_length=4000)


class MessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    conversation_id: str
    sender_id: str
    body: str
    read_at: datetime | None
    created_at: datetime


class ConversationOut(BaseModel):
    id: str
    other_user: UserBrief
    listing_id: str | None
    listing_title: str | None = None
    last_message: MessageOut | None = None
    unread_count: int = 0
    last_message_at: datetime | None
    created_at: datetime


class MarkReadResult(BaseModel):
    marked_read: int
