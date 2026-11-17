import '../../../shared/api/api_client.dart';
import '../../community/models/page_result.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';

/// Talks to /api/chat. The backend has no websockets; screens poll.
class ChatApiService {
  final ApiClient _client;
  ChatApiService(this._client);

  /// Returns the existing conversation with [userId] (for [listingId]) or creates one.
  Future<Conversation> openConversation(String userId, {String? listingId}) async {
    final res = await _client.post('/api/chat/conversations', body: {
      'participant_id': userId,
      if (listingId != null) 'listing_id': listingId,
    });
    return Conversation.fromJson(res as Map<String, dynamic>);
  }

  Future<List<Conversation>> listConversations() async {
    final res = await _client.get('/api/chat/conversations') as List<dynamic>;
    return res.map((e) => Conversation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Conversation> getConversation(String id) async =>
      Conversation.fromJson(await _client.get('/api/chat/conversations/$id') as Map<String, dynamic>);

  /// Newest first.
  Future<PageResult<ChatMessage>> listMessages(String conversationId, {int page = 1, int pageSize = 30}) async {
    final res = await _client.get('/api/chat/conversations/$conversationId/messages',
        query: {'page': page, 'page_size': pageSize});
    return PageResult.fromJson(res as Map<String, dynamic>, ChatMessage.fromJson);
  }

  Future<ChatMessage> sendMessage(String conversationId, String body) async {
    final res = await _client.post('/api/chat/conversations/$conversationId/messages', body: {'body': body});
    return ChatMessage.fromJson(res as Map<String, dynamic>);
  }

  Future<void> markRead(String conversationId) => _client.post('/api/chat/conversations/$conversationId/read');

  /// `{unread_count, poll_interval_seconds}`.
  Future<({int unread, int pollSeconds})> unreadCount() async {
    final res = await _client.get('/api/chat/unread-count') as Map<String, dynamic>;
    return (unread: res['unread_count'] as int, pollSeconds: res['poll_interval_seconds'] as int);
  }
}
