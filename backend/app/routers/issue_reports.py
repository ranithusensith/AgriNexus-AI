"""
/api/issue-reports - content/user reports and admin moderation (Module 3).

Status workflow: open -> reviewed -> resolved | dismissed.
"""
import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.dependencies import get_current_user, require_role
from app.core.permissions import assert_can_view_report
from app.database import get_db
from app.models.community import Comment, Post
from app.models.issue_report import IssueReport, ReportStatus, ReportTargetType
from app.models.product import Listing
from app.models.user import User, UserRole
from app.schemas.common import Page
from app.schemas.issue_report import (
    IssueReportAdminOut, IssueReportCreate, IssueReportOut, IssueReportStatusUpdate,
)
from app.services.user_lookup import load_user_briefs

router = APIRouter(prefix="/api/issue-reports", tags=["issue-reports"])

require_admin = require_role(UserRole.ADMIN)

ALLOWED_TRANSITIONS: dict[ReportStatus, set[ReportStatus]] = {
    ReportStatus.open: {ReportStatus.reviewed},
    ReportStatus.reviewed: {ReportStatus.resolved, ReportStatus.dismissed},
    ReportStatus.resolved: set(),
    ReportStatus.dismissed: set(),
}

_PREVIEW_LEN = 120


def _short(text: str | None) -> str | None:
    if text is None:
        return None
    return text if len(text) <= _PREVIEW_LEN else text[: _PREVIEW_LEN - 1] + "…"


def _target_preview(db: Session, target_type: ReportTargetType, target_id: str) -> str | None:
    """A one-line description of the reported item, or None if it no longer exists."""
    if target_type == ReportTargetType.post:
        post = db.query(Post.title).filter(Post.id == target_id).first()
        return _short(post.title) if post else None
    if target_type == ReportTargetType.comment:
        comment = db.query(Comment.body).filter(Comment.id == target_id).first()
        return _short(comment.body) if comment else None
    if target_type == ReportTargetType.listing:
        listing = db.query(Listing.title).filter(Listing.id == target_id).first()
        return _short(listing.title) if listing else None
    brief = load_user_briefs(db, [target_id]).get(target_id)
    return brief.full_name if brief else None


def _target_exists(db: Session, target_type: ReportTargetType, target_id: str) -> bool:
    if target_type == ReportTargetType.user:
        return db.query(User.id).filter(User.id == uuid.UUID(target_id)).first() is not None
    return _target_preview(db, target_type, target_id) is not None


def _get_report(db: Session, report_id: uuid.UUID) -> IssueReport:
    report = db.query(IssueReport).filter(IssueReport.id == str(report_id)).first()
    if not report:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Report not found")
    return report


def _admin_view(db: Session, reports: list[IssueReport]) -> list[IssueReportAdminOut]:
    briefs = load_user_briefs(db, (r.reporter_id for r in reports))
    return [
        IssueReportAdminOut(
            **IssueReportOut.model_validate(r).model_dump(),
            reporter=briefs.get(str(r.reporter_id)),
            target_preview=_target_preview(db, r.target_type, r.target_id),
        )
        for r in reports
    ]


@router.post("", response_model=IssueReportOut, status_code=status.HTTP_201_CREATED)
def create_report(
    payload: IssueReportCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    target_id = str(payload.target_id)
    if payload.target_type == ReportTargetType.user and target_id == str(current_user.id):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="You cannot report yourself")
    if not _target_exists(db, payload.target_type, target_id):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Reported item not found")

    duplicate = db.query(IssueReport.id).filter(
        IssueReport.reporter_id == str(current_user.id),
        IssueReport.target_type == payload.target_type,
        IssueReport.target_id == target_id,
        IssueReport.status.in_([ReportStatus.open, ReportStatus.reviewed]),
    ).first()
    if duplicate:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="You have already reported this")

    report = IssueReport(
        reporter_id=str(current_user.id),
        target_type=payload.target_type,
        target_id=target_id,
        reason=payload.reason,
        details=payload.details,
    )
    db.add(report)
    db.commit()
    db.refresh(report)
    return report


@router.get("/my", response_model=list[IssueReportOut])
def my_reports(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    return (
        db.query(IssueReport)
        .filter(IssueReport.reporter_id == str(current_user.id))
        .order_by(IssueReport.created_at.desc())
        .all()
    )


@router.get("", response_model=Page[IssueReportAdminOut])
def list_reports(
    status_filter: ReportStatus | None = Query(None, alias="status"),
    target_type: ReportTargetType | None = None,
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=50),
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    query = db.query(IssueReport)
    if status_filter:
        query = query.filter(IssueReport.status == status_filter)
    if target_type:
        query = query.filter(IssueReport.target_type == target_type)
    total = query.count()
    reports = (
        query.order_by(IssueReport.created_at.desc(), IssueReport.id)
        .offset((page - 1) * page_size)
        .limit(page_size)
        .all()
    )
    return Page[IssueReportAdminOut](items=_admin_view(db, reports), total=total, page=page, page_size=page_size)


@router.get("/{report_id}", response_model=IssueReportOut)
def get_report(
    report_id: uuid.UUID,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    report = _get_report(db, report_id)
    assert_can_view_report(report, current_user)
    return report


@router.patch("/{report_id}/status", response_model=IssueReportAdminOut)
def update_report_status(
    report_id: uuid.UUID,
    payload: IssueReportStatusUpdate,
    db: Session = Depends(get_db),
    admin: User = Depends(require_admin),
):
    report = _get_report(db, report_id)
    if payload.status not in ALLOWED_TRANSITIONS[report.status]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Cannot change status from {report.status.value} to {payload.status.value}",
        )
    report.status = payload.status
    report.reviewed_by_id = str(admin.id)
    if payload.admin_note is not None:
        report.admin_note = payload.admin_note
    db.commit()
    db.refresh(report)
    return _admin_view(db, [report])[0]
