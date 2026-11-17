import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/l10n/app_localizations.dart';
import '../../../shared/routes.dart';
import '../../../shared/state/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../community/models/view_status.dart';
import '../../community/widgets/community_labels.dart';
import '../models/conversation.dart';
import '../providers/chat_provider.dart';

/// "Chats": my conversations with last message and unread badge. Polls
/// while open.
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({super.key});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  late final ChatProvider _chat;

  @override
  void initState() {
    super.initState();
    _chat = context.read<ChatProvider>();
    _chat.loadConversations();
    _chat.startPolling();
  }

  @override
  void dispose() {
    _chat.stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final chat = context.watch<ChatProvider>();
    return Scaffold(
      appBar: AppBar(title: Text(t.chats)),
      body: switch (chat.status) {
        ViewStatus.idle || ViewStatus.loading => const LoadingView(),
        ViewStatus.error => ErrorView(
            message: friendlyError(t, chat.error?.statusCode, chat.error?.message ?? t.somethingWentWrong),
            onRetry: chat.loadConversations,
          ),
        ViewStatus.empty => EmptyView(message: t.noConversations, icon: Icons.chat_bubble_outline),
        ViewStatus.success => RefreshIndicator(
            onRefresh: () => chat.loadConversations(silent: true),
            child: ListView.separated(
              itemCount: chat.conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _ConversationTile(conversation: chat.conversations[i]),
            ),
          ),
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final myId = context.read<AuthProvider>().currentUser?.id;
    final last = conversation.lastMessage;
    final unread = conversation.unreadCount;
    final subtitle = <String>[
      if (conversation.listingTitle != null) t.aboutListing(conversation.listingTitle!),
      if (last != null) '${last.senderId == myId ? '${t.you}: ' : ''}${last.body}',
    ].join('\n');

    return ListTile(
      leading: CircleAvatar(child: Text(conversation.otherUser.initial)),
      title: Text(
        conversation.otherUser.fullName,
        style: TextStyle(fontWeight: unread > 0 ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      isThreeLine: conversation.listingTitle != null && last != null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (conversation.lastMessageAt != null)
            Text(formatChatTime(context, conversation.lastMessageAt!), style: Theme.of(context).textTheme.bodySmall),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Badge(label: Text('$unread')),
          ],
        ],
      ),
      onTap: () => Navigator.of(context).pushNamed(AppRoutes.chat, arguments: conversation),
    );
  }
}
