"""
Module 3 - Issue reports: any user can flag a community post, comment,
user or Marketplace listing; admins review them.

`target_id` is polymorphic (it points at a different table per
`target_type`), so it is deliberately NOT a foreign key. Reports outlive
the content they point at, which is what moderators need.
"""
import enum
import uuid

from sqlalchemy import Column, DateTime, Enum, ForeignKey, Index, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func

from app.database import Base


def _uuid() -> str:
    return str(uuid.uuid4())


class ReportTargetType(str, enum.Enum):
    post = "post"
    comment = "comment"
    user = "user"
    listing = "listing"


class ReportReason(str, enum.Enum):
    spam = "spam"
    harassment = "harassment"
    inappropriate = "inappropriate"
    misinformation = "misinformation"
    scam = "scam"
    other = "other"


class ReportStatus(str, enum.Enum):
    open = "open"
    reviewed = "reviewed"
    resolved = "resolved"
    dismissed = "dismissed"


class IssueReport(Base):
    __tablename__ = "issue_reports"

    id = Column(String(36), primary_key=True, default=_uuid)
    reporter_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=False, index=True)
    target_type = Column(Enum(ReportTargetType), nullable=False)
    target_id = Column(String(36), nullable=False)
    reason = Column(Enum(ReportReason), nullable=False)
    details = Column(Text, nullable=True)

    status = Column(Enum(ReportStatus), nullable=False, default=ReportStatus.open, index=True)
    admin_note = Column(Text, nullable=True)
    reviewed_by_id = Column(UUID(as_uuid=False), ForeignKey("users.id"), nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

    __table_args__ = (Index("ix_issue_reports_target", "target_type", "target_id"),)
