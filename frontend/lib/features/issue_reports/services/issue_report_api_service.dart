import '../../../shared/api/api_client.dart';
import '../../community/models/page_result.dart';
import '../models/issue_report.dart';

/// Talks to /api/issue-reports.
class IssueReportApiService {
  final ApiClient _client;
  IssueReportApiService(this._client);

  Future<IssueReport> create({
    required ReportTargetType targetType,
    required String targetId,
    required ReportReason reason,
    String? details,
  }) async {
    final res = await _client.post('/api/issue-reports', body: {
      'target_type': targetType.name,
      'target_id': targetId,
      'reason': reason.name,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
    });
    return IssueReport.fromJson(res as Map<String, dynamic>);
  }

  /// Admin only.
  Future<PageResult<IssueReport>> list({ReportStatus? status, ReportTargetType? targetType, int page = 1, int pageSize = 20}) async {
    final res = await _client.get('/api/issue-reports', query: {
      'status': status?.name,
      'target_type': targetType?.name,
      'page': page,
      'page_size': pageSize,
    });
    return PageResult.fromJson(res as Map<String, dynamic>, IssueReport.fromJson);
  }

  /// Admin only.
  Future<IssueReport> updateStatus(String id, ReportStatus status, {String? adminNote}) async {
    final res = await _client.patch('/api/issue-reports/$id/status', body: {
      'status': status.name,
      if (adminNote != null && adminNote.trim().isNotEmpty) 'admin_note': adminNote.trim(),
    });
    return IssueReport.fromJson(res as Map<String, dynamic>);
  }
}
