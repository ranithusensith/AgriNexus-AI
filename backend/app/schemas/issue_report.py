import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.issue_report import ReportReason, ReportStatus, ReportTargetType
from app.schemas.common import UserBrief


class IssueReportCreate(BaseModel):
    target_type: ReportTargetType
    target_id: uuid.UUID
    reason: ReportReason
    details: str | None = Field(default=None, max_length=2000)


class IssueReportStatusUpdate(BaseModel):
    status: ReportStatus
    admin_note: str | None = Field(default=None, max_length=2000)


class IssueReportOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: str
    reporter_id: str
    target_type: ReportTargetType
    target_id: str
    reason: ReportReason
    details: str | None
    status: ReportStatus
    admin_note: str | None
    reviewed_by_id: str | None
    created_at: datetime
    updated_at: datetime | None


class IssueReportAdminOut(IssueReportOut):
    """Admin view: who reported it and a short preview of the target."""
    reporter: UserBrief | None = None
    target_preview: str | None = None
