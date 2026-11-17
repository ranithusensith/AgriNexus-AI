import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/api/api_exception.dart';
import '../../../shared/l10n/app_localizations.dart';
import '../../community/widgets/community_labels.dart';
import '../models/issue_report.dart';
import '../services/issue_report_api_service.dart';

/// Shows the "Report" dialog for a post, comment, user or listing and
/// submits it. Usable from any module.
Future<void> showReportDialog(BuildContext context, ReportTargetType type, String targetId) async {
  final submitted = await showDialog<bool>(
    context: context,
    builder: (_) => _ReportDialog(type: type, targetId: targetId),
  );
  if (submitted == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).reportSubmitted)));
  }
}

class _ReportDialog extends StatefulWidget {
  final ReportTargetType type;
  final String targetId;
  const _ReportDialog({required this.type, required this.targetId});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  ReportReason _reason = ReportReason.spam;
  final _details = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<IssueReportApiService>().create(
            targetType: widget.type,
            targetId: widget.targetId,
            reason: _reason,
            details: _details.text,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _submitting = false;
        _error = e.statusCode == 409 ? t.alreadyReported : friendlyError(t, e.statusCode, e.message);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.type == ReportTargetType.user ? t.reportUser : t.reportContent),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.reportReason, style: Theme.of(context).textTheme.titleSmall),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v ?? _reason),
              child: Column(
                children: ReportReason.values
                    .map((r) => RadioListTile<ReportReason>(
                          value: r,
                          title: Text(reportReasonLabel(t, r)),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
            ),
            TextField(
              controller: _details,
              maxLines: 3,
              maxLength: 2000,
              decoration: InputDecoration(labelText: t.reportDetails, border: const OutlineInputBorder()),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t.report),
        ),
      ],
    );
  }
}
