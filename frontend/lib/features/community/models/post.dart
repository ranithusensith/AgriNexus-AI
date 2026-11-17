import '../../../shared/api/api_config.dart';
import 'user_brief.dart';

enum PostCategory { general, crops, pestsDiseases, weather, market, equipment, other }

const _categoryWire = {
  PostCategory.general: 'general',
  PostCategory.crops: 'crops',
  PostCategory.pestsDiseases: 'pests_diseases',
  PostCategory.weather: 'weather',
  PostCategory.market: 'market',
  PostCategory.equipment: 'equipment',
  PostCategory.other: 'other',
};

String postCategoryToWire(PostCategory c) => _categoryWire[c]!;

PostCategory postCategoryFromWire(String? value) =>
    _categoryWire.entries.firstWhere((e) => e.value == value, orElse: () => _categoryWire.entries.last).key;

/// The backend returns local uploads as a path ("/uploads/..."); make it absolute.
String? absoluteMediaUrl(String? url) {
  if (url == null || url.isEmpty) return null;
  return url.startsWith('/') ? '${ApiConfig.baseUrl}$url' : url;
}

class Post {
  final String id;
  final UserBrief author;
  final String title;
  final String body;
  final String? imageUrl;
  final PostCategory category;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Post({
    required this.id,
    required this.author,
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.category,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    required this.createdAt,
    this.updatedAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'] as String,
        author: UserBrief.fromJson(json['author'] as Map<String, dynamic>),
        title: json['title'] as String,
        body: json['body'] as String,
        imageUrl: absoluteMediaUrl(json['image_url'] as String?),
        category: postCategoryFromWire(json['category'] as String?),
        likeCount: json['like_count'] as int? ?? 0,
        commentCount: json['comment_count'] as int? ?? 0,
        likedByMe: json['liked_by_me'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        updatedAt: json['updated_at'] == null ? null : DateTime.parse(json['updated_at'] as String).toLocal(),
      );

  Post copyWith({int? likeCount, int? commentCount, bool? likedByMe}) => Post(
        id: id,
        author: author,
        title: title,
        body: body,
        imageUrl: imageUrl,
        category: category,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}
