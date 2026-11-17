import 'package:flutter/foundation.dart';

import '../../../shared/api/api_exception.dart';
import '../models/post.dart';
import '../models/view_status.dart';
import '../services/community_api_service.dart';

/// Community feed: filters, paging and in-place updates after likes/edits.
class CommunityFeedProvider extends ChangeNotifier {
  final CommunityApiService _api;
  CommunityFeedProvider(this._api);

  static const _pageSize = 20;

  List<Post> posts = [];
  ViewStatus status = ViewStatus.idle;
  ApiException? error;
  bool loadingMore = false;

  PostCategory? category;
  String query = '';
  int _page = 1;
  bool _hasMore = false;
  bool get hasMore => _hasMore;

  Future<void> setFilters({PostCategory? category, String? query, bool clearCategory = false}) async {
    if (clearCategory) {
      this.category = null;
    } else if (category != null) {
      this.category = category;
    }
    if (query != null) this.query = query;
    await refresh();
  }

  Future<void> refresh() async {
    status = ViewStatus.loading;
    error = null;
    notifyListeners();
    try {
      final page = await _api.listPosts(category: category, query: query, page: 1, pageSize: _pageSize);
      posts = page.items;
      _page = 1;
      _hasMore = page.hasMore;
      status = posts.isEmpty ? ViewStatus.empty : ViewStatus.success;
    } on ApiException catch (e) {
      error = e;
      status = ViewStatus.error;
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (!_hasMore || loadingMore || status != ViewStatus.success) return;
    loadingMore = true;
    notifyListeners();
    try {
      final page = await _api.listPosts(category: category, query: query, page: _page + 1, pageSize: _pageSize);
      final known = posts.map((p) => p.id).toSet();
      posts = [...posts, ...page.items.where((p) => !known.contains(p.id))];
      _page = page.page;
      _hasMore = page.hasMore;
    } on ApiException catch (e) {
      error = e;
    }
    loadingMore = false;
    notifyListeners();
  }

  /// Optimistic like toggle; reverts on failure and rethrows for the UI.
  Future<Post> toggleLike(Post post) async {
    final liked = !post.likedByMe;
    upsert(post.copyWith(likedByMe: liked, likeCount: post.likeCount + (liked ? 1 : -1)));
    try {
      final count = await _api.setLiked(post.id, liked);
      final updated = post.copyWith(likedByMe: liked, likeCount: count);
      upsert(updated);
      return updated;
    } on ApiException {
      upsert(post);
      rethrow;
    }
  }

  /// Insert a new post at the top, or replace an existing one.
  void upsert(Post post) {
    final i = posts.indexWhere((p) => p.id == post.id);
    if (i >= 0) {
      posts = [...posts]..[i] = post;
    } else {
      posts = [post, ...posts];
      if (status == ViewStatus.empty) status = ViewStatus.success;
    }
    notifyListeners();
  }

  void remove(String postId) {
    posts = posts.where((p) => p.id != postId).toList();
    if (posts.isEmpty && status == ViewStatus.success) status = ViewStatus.empty;
    notifyListeners();
  }
}
