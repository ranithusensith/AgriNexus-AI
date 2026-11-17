import '../../community/models/user_brief.dart';

enum ReportTargetType { post, comment, user, listing }

enum ReportReason { spam, harassment, inappropriate, misinformation, scam, other }

enum ReportStatus { open, reviewed, resolved, dismissed }

T _byName<T extends Enum>(List<T> values, String? name, T fallback) =>
    values.firstWhere((v) => v.name == name, orElse: () => fallback);

/// Allowed admin transitions (mirrors the backend): open -> reviewed -> resolved | dismissed.
const Map<ReportStatus, List<ReportStatus>> kReportTransitions = {
  ReportStatus.open: [ReportStatus.reviewed],
  ReportStatus.reviewed: [ReportStatus.resolved, ReportStatus.dismissed],
  ReportStatus.resolved: [],
  ReportStatus.dismissed: [],
};

class IssueReport {
  final String id;
  final String reporterId;
  final ReportTargetType targetType;
  final String targetId;
  final ReportReason reason;
  final String? details;
  final ReportStatus status;
  final String? adminNote;
  final DateTime createdAt;
  // Admin list only
  final UserBrief? reporter;
  final String? targetPreview;

  const IssueReport({
    required this.id,
    required this.reporterId,
    required this.targetType,
    required this.targetId,
    required this.reason,
    this.details,
    required this.status,
    this.adminNote,
    required this.createdAt,
    this.reporter,
    this.targetPreview,
  });

  factory IssueReport.fromJson(Map<String, dynamic> json) => IssueReport(
        id: json['id'] as String,
        reporterId: json['reporter_id'] as String,
        targetType: _byName(ReportTargetType.values, json['target_type'] as String?, ReportTargetType.post),
        targetId: json['target_id'] as String,
        reason: _byName(ReportReason.values, json['reason'] as String?, ReportReason.other),
        details: json['details'] as String?,
        status: _byName(ReportStatus.values, json['status'] as String?, ReportStatus.open),
        adminNote: json['admin_note'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        reporter: json['reporter'] == null ? null : UserBrief.fromJson(json['reporter'] as Map<String, dynamic>),
        targetPreview: json['target_preview'] as String?,
      );
}
