import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/api/api_exception.dart';
import '../../shared/l10n/app_localizations.dart';
import '../../shared/routes.dart';
import '../community/widgets/community_labels.dart';
import 'providers/chat_provider.dart';

/// Opens (or creates) the 1-to-1 chat with [userId] and shows it.
///
/// Other modules can call this, e.g. a "Chat with seller" button on a
/// Marketplace listing: `openChatWith(context, listing.sellerId, listingId: listing.id)`.
Future<void> openChatWith(BuildContext context, String userId, {String? listingId}) async {
  final t = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  try {
    final conv = await context.read<ChatProvider>().openConversation(userId, listingId: listingId);
    navigator.pushNamed(AppRoutes.chat, arguments: conv);
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(friendlyError(t, e.statusCode, e.message))));
  }
}
