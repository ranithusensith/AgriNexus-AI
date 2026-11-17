"""
/api/chat - 1-to-1 conversations (Module 3).

Real-time delivery is done by client polling: the app re-fetches
GET /conversations and GET /conversations/{id}/messages on an interval
(see CHAT_POLL_INTERVAL_SECONDS). No websockets.
"""
import uuid
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session

from app.config import settings
from app.core.dependencies import get_current_user
from app.core.permissions import assert_conversation_participant
from app.database import get_db
from app.models.chat import Conversation, Message
from app.models.product import Listing
from app.models.user import User
from app.schemas.chat import ConversationCreate, ConversationOut, MarkReadResult, MessageCreate, MessageOut
from app.schemas.common import Page
from app.services.user_lookup import brief_or_placeholder, load_user_briefs

router = APIRouter(prefix="/api/chat", tags=["chat"])


def _get_conversation(db: Session, conversation_id: uuid.UUID, user: User) -> Conversation:
    conv = db.query(Conversation).filter(Conversation.id == str(conversation_id)).first()
    if not conv:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Conversation not found")
    assert_conversation_participant(conv, user)
    return conv


def _unread_filter(user: User):
    return and_(Message.sender_id != str(user.id), Message.read_at.is_(None))


def _summaries(db: Session, convs: list[Conversation], user: User) -> list[ConversationOut]:
    """Build summaries with a fixed number of queries regardless of page size."""
    if not convs:
        return []
    ids = [c.id for c in convs]

    last_messages = {
        m.conversation_id: m
        for m in db.query(Message)
        .filter(Message.conversation_id.in_(ids))
        .distinct(Message.conversation_id)
        .order_by(Message.conversation_id, Message.created_at.desc())
        .all()
    }
    unread = dict(
        db.query(Message.conversation_id, func.count(Message.id))
        .filter(Message.conversation_id.in_(ids), _unread_filter(user))
        .group_by(Message.conversation_id)
        .all()
    )
    listing_ids = {c.listing_id for c in convs if c.listing_id}
    titles = dict(
        db.query(Listing.id, Listing.title).filter(Listing.id.in_(listing_ids)).all()
    ) if listing_ids else {}
    briefs = load_user_briefs(db, (c.other_participant_id(user.id) for c in convs))

    out = []
    for c in convs:
        last = last_messages.get(c.id)
        out.append(ConversationOut(
            id=c.id,
            other_user=brief_or_placeholder(briefs, c.other_participant_id(user.id)),
            listing_id=c.listing_id,
            listing_title=titles.get(c.listing_id),
            last_message=MessageOut.model_validate(last) if last else None,
            unread_count=unread.get(c.id, 0),
            last_message_at=c.last_message_at,
            created_at=c.created_at,
        ))
    return out


@router.post("/conversations", response_model=ConversationOut)
def create_or_get_conversation(
    payload: ConversationCreate,
    response: Response,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Return the existing conversation for this pair (+ listing), or create it (201)."""
    other_id = str(payload.participant_id)
    if other_id == str(current_user.id):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You cannot start a chat with yourself")
    other = db.query(User).filter(User.id == payload.participant_id).first()
    if not other or not other.is_active:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    listing_id = str(payload.listing_id) if payload.listing_id else None
    if listing_id and not db.query(Listing.id).filter(Listing.id == listing_id).first():
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Listing not found")

    a, b = sorted((str(current_user.id), other_id))
    listing_match = Conversation.listing_id == listing_id if listing_id else Conversation.listing_id.is_(None)
    conv = (
        db.query(Conversation)
        .filter(Conversation.user_a_id == a, Conversation.user_b_id == b, listing_match)
        .first()
    )
    if conv is None:
        conv = Conversation(user_a_id=a, user_b_id=b, listing_id=listing_id)
        db.add(conv)
        db.commit()
        db.refresh(conv)
        response.status_code = status.HTTP_201_CREATED
    return _summaries(db, [conv], current_user)[0]


@router.get("/conversations", response_model=list[ConversationOut])
def list_my_conversations(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """My conversations, most recently active first, with last message + unread count."""
    me = str(current_user.id)
    convs = (
        db.query(Conversation)
        .filter(or_(Conversation.user_a_id == me, Conversation.user_b_id == me))
        .order_by(Conversation.last_message_at.desc().nullslast(), Conversation.created_at.desc())
        .all()
    )
    return _summaries(db, convs, current_user)


@router.get("/unread-count")
def unread_count(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Total unread messages across my conversations (for a badge), plus the poll interval."""
    me = str(current_user.id)
    total = (
        db.query(func.count(Message.id))
        .join(Conversation, Conversation.id == Message.conversation_id)
        .filter(or_(Conversation.user_a_id == me, Conversation.user_b_id == me), _unread_filter(current_user))
        .scalar()
    )
    return {"unread_count": total or 0, "poll_interval_seconds": settings.chat_poll_interval_seconds}


@router.get("/conversations/{conversation_id}", response_model=ConversationOut)
def get_conversation(
    conversation_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conv = _get_conversation(db, conversation_id, current_user)
    return _summaries(db, [conv], current_user)[0]


@router.get("/conversations/{conversation_id}/messages", response_model=Page[MessageOut])
def list_messages(
    conversation_id: uuid.UUID,
    page: int = Query(1, ge=1),
    page_size: int = Query(30, ge=1),
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Newest first. Page 1 is what the client polls for new messages."""
    conv = _get_conversation(db, conversation_id, current_user)
    page_size = min(page_size, settings.chat_page_size_max)
    q = db.query(Message).filter(Message.conversation_id == conv.id)
    total = q.count()
    items = (
        q.order_by(Message.created_at.desc(), Message.id.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return Page[MessageOut](items=items, total=total, page=page, page_size=page_size)


@router.post(
    "/conversations/{conversation_id}/messages",
    response_model=MessageOut,
    status_code=status.HTTP_201_CREATED,
)
def send_message(
    conversation_id: uuid.UUID,
    payload: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    conv = _get_conversation(db, conversation_id, current_user)
    body = payload.body.strip()
    if not body:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="Message cannot be empty")
    msg = Message(conversation_id=conv.id, sender_id=str(current_user.id), body=body)
    db.add(msg)
    db.flush()
    conv.last_message_at = msg.created_at
    db.commit()
    db.refresh(msg)
    return msg


@router.post("/conversations/{conversation_id}/read", response_model=MarkReadResult)
def mark_as_read(
    conversation_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Mark every message the other participant sent me in this conversation as read."""
    conv = _get_conversation(db, conversation_id, current_user)
    count = (
        db.query(Message)
        .filter(Message.conversation_id == conv.id, _unread_filter(current_user))
        .update({Message.read_at: datetime.now(timezone.utc)}, synchronize_session=False)
    )
    db.commit()
    return MarkReadResult(marked_read=count)
