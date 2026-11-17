import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/api/api_exception.dart';
import '../../../shared/l10n/app_localizations.dart';
import '../../../shared/state/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../community/models/view_status.dart';
import '../../community/widgets/community_labels.dart';
import '../../issue_reports/models/issue_report.dart';
import '../../issue_reports/widgets/report_dialog.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../providers/chat_provider.dart';

/// One conversation. New messages arrive by polling page 1 every
/// [ChatProvider.pollInterval]; scrolling up loads older pages.
class ChatScreen extends StatefulWidget {
  final Conversation conversation;
  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const _pageSize = 30;

  late final ChatProvider _chat;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  Timer? _poll;

  /// Newest first (the ListView is reversed).
  List<ChatMessage> _messages = [];
  ViewStatus _status = ViewStatus.loading;
  ApiException? _error;
  int _oldestPage = 1;
  bool _hasOlder = false;
  bool _loadingOlder = false;
  bool _sending = false;

  String get _id => widget.conversation.id;

  @override
  void initState() {
    super.initState();
    _chat = context.read<ChatProvider>();
    _chat.startPolling();
    _scroll.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _chat.stopPolling();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _status = ViewStatus.loading;
      _error = null;
    });
    try {
      final page = await _chat.api.listMessages(_id, pageSize: _pageSize);
      if (!mounted) return;
      setState(() {
        _messages = page.items;
        _hasOlder = page.hasMore;
        _oldestPage = 1;
        _status = _messages.isEmpty ? ViewStatus.empty : ViewStatus.success;
      });
      _markReadIfNeeded();
      _poll ??= Timer.periodic(_chat.pollInterval, (_) => _pollNew());
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _status = ViewStatus.error;
      });
    }
  }

  Future<void> _pollNew() async {
    try {
      final page = await _chat.api.listMessages(_id, pageSize: _pageSize);
      if (!mounted) return;
      _merge(page.items);
      _markReadIfNeeded();
    } on ApiException {
      // Keep the current messages; the next tick retries.
    }
  }

  Future<void> _loadOlder() async {
    if (!_hasOlder || _loadingOlder) return;
    setState(() => _loadingOlder = true);
    try {
      final page = await _chat.api.listMessages(_id, page: _oldestPage + 1, pageSize: _pageSize);
      if (!mounted) return;
      _oldestPage = page.page;
      _hasOlder = page.hasMore;
      _merge(page.items);
    } on ApiException catch (e) {
      _showError(e);
    }
    if (mounted) setState(() => _loadingOlder = false);
  }

  void _onScroll() {
    // Reversed list: maxScrollExtent is the top (oldest messages).
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) _loadOlder();
  }

  /// Merge by id and keep newest-first order (polls overlap with what we have).
  void _merge(List<ChatMessage> incoming) {
    final byId = {for (final m in _messages) m.id: m, for (final m in incoming) m.id: m};
    final merged = byId.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    setState(() {
      _messages = merged;
      _status = merged.isEmpty ? ViewStatus.empty : ViewStatus.success;
    });
  }

  Future<void> _markReadIfNeeded() async {
    final myId = context.read<AuthProvider>().currentUser?.id;
    final hasUnread = _messages.any((m) => m.senderId != myId && m.readAt == null);
    if (!hasUnread) return;
    try {
      await _chat.api.markRead(_id);
      _chat.markLocallyRead(_id);
      // Reflect read_at locally so we don't call again on the next poll.
      final now = DateTime.now();
      if (!mounted) return;
      setState(() {
        _messages = [
          for (final m in _messages)
            m.senderId != myId && m.readAt == null
                ? ChatMessage(
                    id: m.id, conversationId: m.conversationId, senderId: m.senderId,
                    body: m.body, readAt: now, createdAt: m.createdAt)
                : m,
        ];
      });
    } on ApiException {
      // Not critical; retried on the next poll.
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final msg = await _chat.api.sendMessage(_id, text);
      _input.clear();
      _merge([msg]);
      _chat.loadConversations(silent: true);
    } on ApiException catch (e) {
      _showError(e);
    }
    if (mounted) setState(() => _sending = false);
  }

  void _showError(ApiException e) {
    if (!mounted) return;
    final t = AppLocalizations.of(context);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(friendlyError(t, e.statusCode, e.message))));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final conv = widget.conversation;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(conv.otherUser.fullName),
            Text(
              conv.listingTitle != null ? t.aboutListing(conv.listingTitle!) : roleLabel(t, conv.otherUser.role),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (_) => showReportDialog(context, ReportTargetType.user, conv.otherUser.id),
            itemBuilder: (_) => [PopupMenuItem(value: 'report', child: Text(t.reportUser))],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildMessages(t)),
          const Divider(height: 1),
          _Composer(controller: _input, sending: _sending, onSend: _send),
        ],
      ),
    );
  }

  Widget _buildMessages(AppLocalizations t) {
    switch (_status) {
      case ViewStatus.idle:
      case ViewStatus.loading:
        return const LoadingView();
      case ViewStatus.error:
        return ErrorView(
          message: friendlyError(t, _error?.statusCode, _error?.message ?? t.somethingWentWrong),
          onRetry: _loadInitial,
        );
      case ViewStatus.empty:
        return EmptyView(message: t.noMessages, icon: Icons.waving_hand_outlined);
      case ViewStatus.success:
        final myId = context.read<AuthProvider>().currentUser?.id;
        return ListView.builder(
          controller: _scroll,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: _messages.length + (_loadingOlder ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _messages.length) {
              return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
            }
            final m = _messages[i];
            return _Bubble(message: m, mine: m.senderId == myId);
          },
        );
    }
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  const _Bubble({required this.message, required this.mine});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = mine ? scheme.onPrimaryContainer : scheme.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: mine ? scheme.primaryContainer : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(message.body, style: TextStyle(color: fg)),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatChatTime(context, message.createdAt),
                      style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.7))),
                  if (mine) ...[
                    const SizedBox(width: 4),
                    Icon(message.readAt != null ? Icons.done_all : Icons.done, size: 14, color: fg.withValues(alpha: 0.7)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  const _Composer({required this.controller, required this.sending, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: t.typeMessage, counterText: '', border: const OutlineInputBorder()),
              ),
            ),
            IconButton(
              tooltip: t.send,
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
