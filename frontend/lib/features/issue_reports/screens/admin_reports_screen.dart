import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/api/api_exception.dart';
import '../../../shared/l10n/app_localizations.dart';
import '../../../shared/routes.dart';
import '../../../shared/state/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../community/models/view_status.dart';
import '../../community/widgets/community_labels.dart';
import '../models/issue_report.dart';
import '../services/issue_report_api_service.dart';

/// Admin moderation queue: filter by status, move reports through
/// open -> reviewed -> resolved | dismissed.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  ReportStatus? _filter = ReportStatus.open;
  List<IssueReport> _reports = [];
  ViewStatus _status = ViewStatus.loading;
  ApiException? _error;
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  IssueReportApiService get _api => context.read<IssueReportApiService>();

  Future<void> _load() async {
    setState(() {
      _status = ViewStatus.loading;
      _error = null;
    });
    try {
      final page = await _api.list(status: _filter);
      if (!mounted) return;
      setState(() {
        _reports = page.items;
        _page = 1;
        _hasMore = page.hasMore;
        _status = _reports.isEmpty ? ViewStatus.empty : ViewStatus.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _status = ViewStatus.error;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _api.list(status: _filter, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _reports = [..._reports, ...page.items];
        _page = page.page;
        _hasMore = page.hasMore;
      });
    } on ApiException catch (e) {
      _snack(friendlyError(AppLocalizations.of(context), e.statusCode, e.message));
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  Future<void> _changeStatus(IssueReport report, ReportStatus next) async {
    final t = AppLocalizations.of(context);
    final note = await _askNote(t, next);
    if (note == null) return; // cancelled
    try {
      final updated = await _api.updateStatus(report.id, next, adminNote: note);
      if (!mounted) return;
      setState(() {
        // Drop it from a filtered list it no longer matches.
        _reports = [
          for (final r in _reports)
            if (r.id != report.id) r else if (_filter == null || _filter == updated.status) updated,
        ];
        if (_reports.isEmpty) _status = ViewStatus.empty;
      });
      _snack(t.reportUpdated);
    } on ApiException catch (e) {
      _snack(friendlyError(t, e.statusCode, e.message));
    }
  }

  Future<String?> _askNote(AppLocalizations t, ReportStatus next) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(reportStatusLabel(t, next)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 2000,
          decoration: InputDecoration(labelText: t.adminNote, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: Text(t.confirm)),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final isAdmin = context.watch<AuthProvider>().currentUser?.role == 'admin';
    return Scaffold(
      appBar: AppBar(title: Text(t.adminReports)),
      body: !isAdmin
          ? ErrorView(message: t.adminOnly)
          : Column(
              children: [
                SizedBox(
                  height: 56,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      _chip(t.filterAll, null),
                      for (final s in ReportStatus.values) _chip(reportStatusLabel(t, s), s),
                    ],
                  ),
                ),
                Expanded(child: _buildList(t)),
              ],
            ),
    );
  }

  Widget _chip(String label, ReportStatus? value) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) {
            setState(() => _filter = value);
            _load();
          },
        ),
      );

  Widget _buildList(AppLocalizations t) {
    switch (_status) {
      case ViewStatus.idle:
      case ViewStatus.loading:
        return const LoadingView();
      case ViewStatus.error:
        return ErrorView(
          message: friendlyError(t, _error?.statusCode, _error?.message ?? t.somethingWentWrong),
          onRetry: _load,
        );
      case ViewStatus.empty:
        return EmptyView(message: t.noReports, icon: Icons.flag_outlined);
      case ViewStatus.success:
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _reports.length + (_loadingMore ? 1 : 0),
            itemBuilder: (_, i) => i == _reports.length
                ? const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
                : _ReportCard(report: _reports[i], onChangeStatus: _changeStatus),
          ),
        );
    }
  }
}

class _ReportCard extends StatelessWidget {
  final IssueReport report;
  final void Function(IssueReport, ReportStatus) onChangeStatus;
  const _ReportCard({required this.report, required this.onChangeStatus});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final next = kReportTransitions[report.status]!;
    final canOpenPost = report.targetType == ReportTargetType.post && report.targetPreview != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusChip(label: reportTargetLabel(t, report.targetType), color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                StatusChip(label: reportReasonLabel(t, report.reason), color: Colors.redAccent),
                const Spacer(),
                StatusChip(label: reportStatusLabel(t, report.status), color: reportStatusColor(report.status)),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: canOpenPost
                  ? () => Navigator.of(context).pushNamed(AppRoutes.communityPost, arguments: report.targetId)
                  : null,
              child: Text(
                report.targetPreview ?? t.targetDeleted,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontStyle: report.targetPreview == null ? FontStyle.italic : null,
                  decoration: canOpenPost ? TextDecoration.underline : null,
                ),
              ),
            ),
            if (report.details != null && report.details!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(report.details!),
            ],
            if (report.adminNote != null && report.adminNote!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('${t.adminNote}: ${report.adminNote!}', style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 6),
            Text(
              '${t.reportedBy(report.reporter?.fullName ?? report.reporterId)} · ${formatDateTime(context, report.createdAt)}',
              style: theme.textTheme.bodySmall,
            ),
            if (next.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final s in next)
                    OutlinedButton(
                      onPressed: () => onChangeStatus(report, s),
                      child: Text(switch (s) {
                        ReportStatus.reviewed => t.markReviewed,
                        ReportStatus.resolved => t.resolve,
                        ReportStatus.dismissed => t.dismiss,
                        ReportStatus.open => t.reportStatusOpen,
                      }),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
