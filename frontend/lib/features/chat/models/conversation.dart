import '../../community/models/user_brief.dart';
import 'chat_message.dart';

class Conversation {
  final String id;
  final UserBrief otherUser;
  final String? listingId;
  final String? listingTitle;
  final ChatMessage? lastMessage;
  final int unreadCount;
  final DateTime? lastMessageAt;
  final DateTime createdAt;

  const Conversation({
    required this.id,
    required this.otherUser,
    this.listingId,
    this.listingTitle,
    this.lastMessage,
    required this.unreadCount,
    this.lastMessageAt,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        otherUser: UserBrief.fromJson(json['other_user'] as Map<String, dynamic>),
        listingId: json['listing_id'] as String?,
        listingTitle: json['listing_title'] as String?,
        lastMessage: json['last_message'] == null
            ? null
            : ChatMessage.fromJson(json['last_message'] as Map<String, dynamic>),
        unreadCount: json['unread_count'] as int? ?? 0,
        lastMessageAt:
            json['last_message_at'] == null ? null : DateTime.parse(json['last_message_at'] as String).toLocal(),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
