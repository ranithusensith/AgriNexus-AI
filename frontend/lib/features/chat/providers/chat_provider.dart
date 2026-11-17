import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/api/api_exception.dart';
import '../../community/models/view_status.dart';
import '../models/conversation.dart';
import '../services/chat_api_service.dart';

/// Conversation list + total unread count, kept fresh by polling while a
/// chat screen is visible (the backend has no push/websocket channel).
class ChatProvider extends ChangeNotifier {
  final ChatApiService _api;
  ChatProvider(this._api);

  List<Conversation> conversations = [];
  ViewStatus status = ViewStatus.idle;
  ApiException? error;
  int unreadTotal = 0;

  /// Server-advertised poll interval (GET /api/chat/unread-count).
  Duration pollInterval = const Duration(seconds: 5);

  Timer? _timer;
  int _pollers = 0;

  ChatApiService get api => _api;

  Future<void> loadConversations({bool silent = false}) async {
    if (!silent) {
      status = ViewStatus.loading;
      error = null;
      notifyListeners();
    }
    try {
      conversations = await _api.listConversations();
      unreadTotal = conversations.fold(0, (sum, c) => sum + c.unreadCount);
      status = conversations.isEmpty ? ViewStatus.empty : ViewStatus.success;
      error = null;
    } on ApiException catch (e) {
      // A failed background poll keeps showing the last good list.
      if (!silent || status != ViewStatus.success) {
        error = e;
        status = ViewStatus.error;
      }
    }
    notifyListeners();
  }

  Future<void> refreshUnread() async {
    try {
      final r = await _api.unreadCount();
      unreadTotal = r.unread;
      if (r.pollSeconds > 0) pollInterval = Duration(seconds: r.pollSeconds);
      notifyListeners();
    } on ApiException {
      // Badge is best-effort.
    }
  }

  Future<Conversation> openConversation(String userId, {String? listingId}) async {
    final conv = await _api.openConversation(userId, listingId: listingId);
    if (!conversations.any((c) => c.id == conv.id)) {
      conversations = [conv, ...conversations];
      status = ViewStatus.success;
      notifyListeners();
    }
    return conv;
  }

  /// Called by screens that want the list kept fresh; reference-counted so
  /// nested chat screens don't stop each other's polling.
  void startPolling() {
    _pollers++;
    if (_timer != null) return;
    refreshUnread().then((_) {
      if (_pollers == 0 || _timer != null) return;
      _timer = Timer.periodic(pollInterval, (_) => loadConversations(silent: true));
    });
  }

  void stopPolling() {
    if (_pollers > 0) _pollers--;
    if (_pollers == 0) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Clear the badge for a conversation the user just read.
  void markLocallyRead(String conversationId) {
    final i = conversations.indexWhere((c) => c.id == conversationId);
    if (i < 0 || conversations[i].unreadCount == 0) return;
    final c = conversations[i];
    unreadTotal = (unreadTotal - c.unreadCount).clamp(0, 1 << 31);
    conversations = [...conversations]
      ..[i] = Conversation(
        id: c.id,
        otherUser: c.otherUser,
        listingId: c.listingId,
        listingTitle: c.listingTitle,
        lastMessage: c.lastMessage,
        unreadCount: 0,
        lastMessageAt: c.lastMessageAt,
        createdAt: c.createdAt,
      );
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
