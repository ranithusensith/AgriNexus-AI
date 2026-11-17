import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/api/api_exception.dart';
import '../../../shared/l10n/app_localizations.dart';
import '../../../shared/routes.dart';
import '../../../shared/state/auth_provider.dart';
import '../../../shared/widgets/common_widgets.dart';
import '../../chat/providers/chat_provider.dart';
import '../models/post.dart';
import '../models/view_status.dart';
import '../providers/community_feed_provider.dart';
import '../widgets/community_labels.dart';
import '../widgets/post_card.dart';

/// Module 3 entry screen: community feed with search + category filter.
class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});

  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final feed = context.read<CommunityFeedProvider>();
    _search.text = feed.query;
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) feed.loadMore();
    });
    feed.refresh();
    context.read<ChatProvider>().refreshUnread();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _like(Post post) async {
    final t = AppLocalizations.of(context);
    try {
      await context.read<CommunityFeedProvider>().toggleLike(post);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(t, e.statusCode, e.message))));
      }
    }
  }

  Future<void> _openPost(Post post) async {
    await Navigator.of(context).pushNamed(AppRoutes.communityPost, arguments: post.id);
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).pushNamed(AppRoutes.createPost);
    if (created is Post && mounted) context.read<CommunityFeedProvider>().upsert(created);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final feed = context.watch<CommunityFeedProvider>();
    final unread = context.watch<ChatProvider>().unreadTotal;
    final isAdmin = context.watch<AuthProvider>().currentUser?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(t.community),
        actions: [
          IconButton(
            tooltip: t.chats,
            icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.chat_outlined)),
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.conversations),
          ),
          if (isAdmin)
            IconButton(
              tooltip: t.adminReports,
              icon: const Icon(Icons.flag_outlined),
              onPressed: () => Navigator.of(context).pushNamed(AppRoutes.adminReports),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.edit_outlined),
        label: Text(t.newPost),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: t.searchPosts,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: feed.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          feed.setFilters(query: '');
                        },
                      ),
              ),
              onSubmitted: (q) => feed.setFilters(query: q),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t.filterAll),
                    selected: feed.category == null,
                    onSelected: (_) => feed.setFilters(clearCategory: true),
                  ),
                ),
                for (final c in PostCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(postCategoryLabel(t, c)),
                      selected: feed.category == c,
                      onSelected: (_) => feed.setFilters(category: c),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildBody(t, feed)),
        ],
      ),
    );
  }

  Widget _buildBody(AppLocalizations t, CommunityFeedProvider feed) {
    switch (feed.status) {
      case ViewStatus.idle:
      case ViewStatus.loading:
        return const LoadingView();
      case ViewStatus.error:
        return ErrorView(
          message: friendlyError(t, feed.error?.statusCode, feed.error?.message ?? t.somethingWentWrong),
          onRetry: feed.refresh,
        );
      case ViewStatus.empty:
        return RefreshIndicator(
          onRefresh: feed.refresh,
          child: ListView(children: [
            const SizedBox(height: 80),
            EmptyView(message: t.noPosts, icon: Icons.forum_outlined),
          ]),
        );
      case ViewStatus.success:
        return RefreshIndicator(
          onRefresh: feed.refresh,
          child: ListView.builder(
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: feed.posts.length + (feed.loadingMore ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == feed.posts.length) {
                return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
              }
              final post = feed.posts[i];
              return PostCard(post: post, onTap: () => _openPost(post), onLike: () => _like(post));
            },
          ),
        );
    }
  }
}
