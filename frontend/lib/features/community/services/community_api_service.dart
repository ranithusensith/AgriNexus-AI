import 'dart:io';

import '../../../shared/api/api_client.dart';
import '../models/comment.dart';
import '../models/page_result.dart';
import '../models/post.dart';

/// Talks to /api/community. Throws ApiException on failure (via ApiClient).
class CommunityApiService {
  final ApiClient _client;
  CommunityApiService(this._client);

  Future<PageResult<Post>> listPosts({
    PostCategory? category,
    String? authorId,
    String? query,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _client.get('/api/community/posts', query: {
      'category': category == null ? null : postCategoryToWire(category),
      'author_id': authorId,
      'q': (query == null || query.trim().isEmpty) ? null : query.trim(),
      'page': page,
      'page_size': pageSize,
    });
    return PageResult.fromJson(res as Map<String, dynamic>, Post.fromJson);
  }

  Future<Post> getPost(String id) async =>
      Post.fromJson(await _client.get('/api/community/posts/$id') as Map<String, dynamic>);

  Future<Post> createPost({required String title, required String body, required PostCategory category}) async {
    final res = await _client.post('/api/community/posts',
        body: {'title': title, 'body': body, 'category': postCategoryToWire(category)});
    return Post.fromJson(res as Map<String, dynamic>);
  }

  Future<Post> updatePost(String id, {required String title, required String body, required PostCategory category}) async {
    final res = await _client.put('/api/community/posts/$id',
        body: {'title': title, 'body': body, 'category': postCategoryToWire(category)});
    return Post.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deletePost(String id) => _client.delete('/api/community/posts/$id');

  Future<Post> uploadPostImage(String id, File file) async {
    final res = await _client.uploadFile('/api/community/posts/$id/image', file: file, fieldName: 'file');
    return Post.fromJson(res as Map<String, dynamic>);
  }

  Future<Post> removePostImage(String id) async =>
      Post.fromJson(await _client.delete('/api/community/posts/$id/image') as Map<String, dynamic>);

  /// Returns the new like count.
  Future<int> setLiked(String postId, bool liked) async {
    final path = '/api/community/posts/$postId/like';
    final res = (liked ? await _client.post(path) : await _client.delete(path)) as Map<String, dynamic>;
    return res['like_count'] as int;
  }

  Future<PageResult<Comment>> listComments(String postId, {int page = 1, int pageSize = 30}) async {
    final res = await _client.get('/api/community/posts/$postId/comments', query: {'page': page, 'page_size': pageSize});
    return PageResult.fromJson(res as Map<String, dynamic>, Comment.fromJson);
  }

  Future<Comment> addComment(String postId, String body) async {
    final res = await _client.post('/api/community/posts/$postId/comments', body: {'body': body});
    return Comment.fromJson(res as Map<String, dynamic>);
  }

  Future<Comment> updateComment(String commentId, String body) async {
    final res = await _client.put('/api/community/comments/$commentId', body: {'body': body});
    return Comment.fromJson(res as Map<String, dynamic>);
  }

  Future<void> deleteComment(String commentId) => _client.delete('/api/community/comments/$commentId');
}
