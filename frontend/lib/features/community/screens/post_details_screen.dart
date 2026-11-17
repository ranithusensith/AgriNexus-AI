import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/api/api_exception.dart';
import '../../../shared/l10n/app_localizations.dart';
import '../../../shared/routes.dart';
import '../../../shared/state/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../chat/chat_launcher.dart';
import '../../issue_reports/models/issue_report.dart';
import '../../issue_reports/widgets/report_dialog.dart';
import '../models/comment.dart';
import '../models/page_result.dart';
import '../models/post.dart';
import '../models/view_status.dart';
import '../providers/community_feed_provider.dart';
import '../services/community_api_service.dart';
import '../widgets/community_labels.dart';
import '../widgets/post_card.dart';

enum _PostAction { edit, delete, report, reportUser, message }

enum _CommentAction { edit, delete, report }

/// A post with its comment thread and a comment composer.
class PostDetailsScreen extends StatefulWidget {
  final String postId;
  const PostDetailsScreen({super.key, required this.postId});

  @override
  State<PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<PostDetailsScreen> {
  static const _pageSize = 30;

  Post? _post;
  List<Comment> _comments = [];
  ViewStatus _status = ViewStatus.loading;
  String? _errorMessage;
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _sending = false;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  CommunityApiService get _api => context.read<CommunityApiService>();
  AppLocalizations get _t => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) _loadMoreComments();
    });
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _status = ViewStatus.loading;
      _errorMessage = null;
    });
    try {
      final results = await Future.wait([
        _api.getPost(widget.postId),
        _api.listComments(widget.postId, pageSize: _pageSize),
      ]);
      if (!mounted) return;
      final post = results[0] as Post;
      final page = results[1] as PageResult<Comment>;
      setState(() {
        _post = post;
        _comments = page.items;
        _page = 1;
        _hasMore = page.hasMore;
        _status = ViewStatus.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.isNotFound) context.read<CommunityFeedProvider>().remove(widget.postId);
      setState(() {
        _errorMessage = e.isNotFound ? _t.postNotFound : friendlyError(_t, e.statusCode, e.message);
        _status = ViewStatus.error;
      });
    }
  }

  Future<void> _loadMoreComments() async {
    if (!_hasMore || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _api.listComments(widget.postId, page: _page + 1, pageSize: _pageSize);
      if (!mounted) return;
      final known = _comments.map((c) => c.id).toSet();
      setState(() {
        _comments = [..._comments, ...page.items.where((c) => !known.contains(c.id))];
        _page = page.page;
        _hasMore = page.hasMore;
      });
    } on ApiException catch (e) {
      _snack(friendlyError(_t, e.statusCode, e.message));
    }
    if (mounted) setState(() => _loadingMore = false);
  }

  void _setPost(Post post) {
    setState(() => _post = post);
    context.read<CommunityFeedProvider>().upsert(post);
  }

  Future<void> _like() async {
    final post = _post!;
    final liked = !post.likedByMe;
    setState(() => _post = post.copyWith(likedByMe: liked, likeCount: post.likeCount + (liked ? 1 : -1)));
    try {
      final count = await _api.setLiked(post.id, liked);
      if (mounted) _setPost(post.copyWith(likedByMe: liked, likeCount: count));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _post = post);
      _snack(friendlyError(_t, e.statusCode, e.message));
    }
  }

  Future<void> _sendComment() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final comment = await _api.addComment(widget.postId, text);
      if (!mounted) return;
      _input.clear();
      FocusScope.of(context).unfocus();
      setState(() {
        // Comments are oldest-first; only append if we've loaded the tail.
        if (!_hasMore) _comments = [..._comments, comment];
      });
      _setPost(_post!.copyWith(commentCount: _post!.commentCount + 1));
    } on ApiException catch (e) {
      _snack(friendlyError(_t, e.statusCode, e.message));
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _onPostAction(_PostAction action) async {
    final post = _post!;
    switch (action) {
      case _PostAction.edit:
        final updated = await Navigator.of(context).pushNamed(AppRoutes.createPost, arguments: post);
        if (updated is Post && mounted) _setPost(updated);
      case _PostAction.delete:
        if (!await _confirm(_t.deletePost, _t.confirmDeletePost)) return;
        try {
          await _api.deletePost(post.id);
          if (!mounted) return;
          context.read<CommunityFeedProvider>().remove(post.id);
          Navigator.of(context).pop();
        } on ApiException catch (e) {
          _snack(friendlyError(_t, e.statusCode, e.message));
        }
      case _PostAction.report:
        await showReportDialog(context, ReportTargetType.post, post.id);
      case _PostAction.reportUser:
        await showReportDialog(context, ReportTargetType.user, post.author.id);
      case _PostAction.message:
        await openChatWith(context, post.author.id);
    }
  }

  Future<void> _onCommentAction(Comment comment, _CommentAction action) async {
    switch (action) {
      case _CommentAction.edit:
        final text = await _editCommentDialog(comment.body);
        if (text == null || text.trim().isEmpty || text.trim() == comment.body) return;
        try {
          final updated = await _api.updateComment(comment.id, text.trim());
          if (!mounted) return;
          setState(() => _comments = [for (final c in _comments) c.id == comment.id ? updated : c]);
        } on ApiException catch (e) {
          _snack(friendlyError(_t, e.statusCode, e.message));
        }
      case _CommentAction.delete:
        if (!await _confirm(_t.deleteComment, _t.confirmDeleteComment)) return;
        try {
          await _api.deleteComment(comment.id);
          if (!mounted) return;
          setState(() => _comments = _comments.where((c) => c.id != comment.id).toList());
          _setPost(_post!.copyWith(commentCount: (_post!.commentCount - 1).clamp(0, 1 << 31)));
        } on ApiException catch (e) {
          _snack(friendlyError(_t, e.statusCode, e.message));
        }
      case _CommentAction.report:
        await showReportDialog(context, ReportTargetType.comment, comment.id);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(_t.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(_t.delete)),
        ],
      ),
    );
    return ok == true;
  }

  Future<String?> _editCommentDialog(String initial) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_t.editComment),
        content: TextField(controller: controller, maxLines: 4, maxLength: 4000, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(_t.cancel)),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(controller.text), child: Text(_t.save)),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final me = context.watch<AuthProvider>().currentUser;
    final isAdmin = me?.role == 'admin';
    final post = _post;
    final isAuthor = post != null && post.author.id == me?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.comments),
        actions: [
          if (post != null)
            PopupMenuButton<_PostAction>(
              onSelected: _onPostAction,
              itemBuilder: (_) => [
                if (isAuthor) PopupMenuItem(value: _PostAction.edit, child: Text(t.editPost)),
                if (isAuthor || isAdmin) PopupMenuItem(value: _PostAction.delete, child: Text(t.deletePost)),
                if (!isAuthor) ...[
                  PopupMenuItem(value: _PostAction.message, child: Text(t.messageAuthor)),
                  PopupMenuItem(value: _PostAction.report, child: Text(t.reportContent)),
                  PopupMenuItem(value: _PostAction.reportUser, child: Text(t.reportUser)),
                ],
              ],
            ),
        ],
      ),
      body: switch (_status) {
        ViewStatus.idle || ViewStatus.loading => const LoadingView(),
        ViewStatus.error || ViewStatus.empty =>
          ErrorView(message: _errorMessage ?? t.somethingWentWrong, onRetry: _load),
        ViewStatus.success => Column(
            children: [
              Expanded(child: _buildThread(t, post!, me?.id, isAdmin)),
              const Divider(height: 1),
              _buildComposer(t),
            ],
          ),
      },
    );
  }

  Widget _buildThread(AppLocalizations t, Post post, String? myId, bool isAdmin) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          AuthorRow(post: post),
          const SizedBox(height: 12),
          Text(post.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Chip(label: Text(postCategoryLabel(t, post.category)), visualDensity: VisualDensity.compact),
          ),
          const SizedBox(height: 8),
          SelectableText(post.body),
          if (post.imageUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 120,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
          ],
          Row(
            children: [
              LikeButton(liked: post.likedByMe, count: post.likeCount, onPressed: _like),
              const SizedBox(width: 8),
              const Icon(Icons.chat_bubble_outline, size: 20),
              const SizedBox(width: 4),
              Text('${post.commentCount}'),
            ],
          ),
          const Divider(),
          if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text(t.noComments, style: const TextStyle(color: Colors.grey))),
            ),
          for (final c in _comments) _commentTile(t, c, myId, isAdmin),
          if (_loadingMore) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _commentTile(AppLocalizations t, Comment c, String? myId, bool isAdmin) {
    final mine = c.author.id == myId;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(radius: 16, child: Text(c.author.initial)),
      title: Text(c.author.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(c.body, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 2),
          Text(formatDateTime(context, c.createdAt), style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      trailing: PopupMenuButton<_CommentAction>(
        onSelected: (a) => _onCommentAction(c, a),
        itemBuilder: (_) => [
          if (mine) PopupMenuItem(value: _CommentAction.edit, child: Text(t.editComment)),
          if (mine || isAdmin) PopupMenuItem(value: _CommentAction.delete, child: Text(t.deleteComment)),
          if (!mine) PopupMenuItem(value: _CommentAction.report, child: Text(t.report)),
        ],
      ),
    );
  }

  Widget _buildComposer(AppLocalizations t) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: t.writeComment, counterText: '', border: const OutlineInputBorder()),
              ),
            ),
            IconButton(
              tooltip: t.send,
              onPressed: _sending ? null : _sendComment,
              icon: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
