import 'package:flutter/material.dart';

import '../../../shared/l10n/app_localizations.dart';
import '../models/post.dart';
import 'community_labels.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  const PostCard({super.key, required this.post, required this.onTap, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AuthorRow(post: post),
              const SizedBox(height: 8),
              Text(post.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(post.body, maxLines: 3, overflow: TextOverflow.ellipsis),
              if (post.imageUrl != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      post.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Colors.black12,
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Row(
                children: [
                  Chip(
                    label: Text(postCategoryLabel(t, post.category)),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  const Spacer(),
                  LikeButton(liked: post.likedByMe, count: post.likeCount, onPressed: onLike),
                  const SizedBox(width: 8),
                  const Icon(Icons.chat_bubble_outline, size: 20),
                  const SizedBox(width: 4),
                  Text('${post.commentCount}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthorRow extends StatelessWidget {
  final Post post;
  const AuthorRow({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return Row(
      children: [
        CircleAvatar(radius: 16, child: Text(post.author.initial)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.author.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${roleLabel(t, post.author.role)} · ${formatDateTime(context, post.createdAt)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LikeButton extends StatelessWidget {
  final bool liked;
  final int count;
  final VoidCallback onPressed;
  const LikeButton({super.key, required this.liked, required this.count, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(liked ? Icons.thumb_up : Icons.thumb_up_outlined, size: 20),
      label: Text('$count'),
    );
  }
}
