import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../shared/l10n/app_localizations.dart';
import '../../issue_reports/models/issue_report.dart';
import '../models/post.dart';

/// Localized labels for Module 3 enums, kept in one place.
String postCategoryLabel(AppLocalizations t, PostCategory c) => switch (c) {
      PostCategory.general => t.categoryGeneral,
      PostCategory.crops => t.categoryCrops,
      PostCategory.pestsDiseases => t.categoryPestsDiseases,
      PostCategory.weather => t.categoryWeather,
      PostCategory.market => t.categoryMarket,
      PostCategory.equipment => t.categoryEquipment,
      PostCategory.other => t.categoryOther,
    };

String roleLabel(AppLocalizations t, String role) => switch (role) {
      'farmer' => t.roleFarmer,
      'buyer' => t.roleBuyer,
      'supplier' => t.roleSupplier,
      'admin' => t.roleAdmin,
      'community_member' => t.roleCommunityMember,
      _ => role,
    };

String reportReasonLabel(AppLocalizations t, ReportReason r) => switch (r) {
      ReportReason.spam => t.reasonSpam,
      ReportReason.harassment => t.reasonHarassment,
      ReportReason.inappropriate => t.reasonInappropriate,
      ReportReason.misinformation => t.reasonMisinformation,
      ReportReason.scam => t.reasonScam,
      ReportReason.other => t.reasonOther,
    };

String reportStatusLabel(AppLocalizations t, ReportStatus s) => switch (s) {
      ReportStatus.open => t.reportStatusOpen,
      ReportStatus.reviewed => t.reportStatusReviewed,
      ReportStatus.resolved => t.reportStatusResolved,
      ReportStatus.dismissed => t.reportStatusDismissed,
    };

Color reportStatusColor(ReportStatus s) => switch (s) {
      ReportStatus.open => Colors.orange,
      ReportStatus.reviewed => Colors.blue,
      ReportStatus.resolved => Colors.green,
      ReportStatus.dismissed => Colors.grey,
    };

String reportTargetLabel(AppLocalizations t, ReportTargetType type) => switch (type) {
      ReportTargetType.post => t.targetPost,
      ReportTargetType.comment => t.targetComment,
      ReportTargetType.user => t.targetUser,
      ReportTargetType.listing => t.targetListing,
    };

/// Date + time in the app's current language.
String formatDateTime(BuildContext context, DateTime dt) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toString()).add_jm().format(dt);

/// Time only for today, date + time otherwise (chat bubbles, conversation list).
String formatChatTime(BuildContext context, DateTime dt) {
  final locale = Localizations.localeOf(context).toString();
  final now = DateTime.now();
  final sameDay = dt.year == now.year && dt.month == now.month && dt.day == now.day;
  return sameDay ? DateFormat.jm(locale).format(dt) : DateFormat.MMMd(locale).add_jm().format(dt);
}

/// Maps a failed request to a message, preferring our own wording for 403.
String friendlyError(AppLocalizations t, int? statusCode, String serverMessage) {
  if (statusCode == 403) return t.notAllowed;
  if (statusCode == null) return t.networkError;
  return serverMessage;
}
