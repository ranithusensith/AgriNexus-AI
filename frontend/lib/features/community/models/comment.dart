import 'user_brief.dart';

class Comment {
  final String id;
  final String postId;
  final UserBrief author;
  final String body;
  final DateTime createdAt;

  const Comment({required this.id, required this.postId, required this.author, required this.body, required this.createdAt});

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
        id: json['id'] as String,
        postId: json['post_id'] as String,
        author: UserBrief.fromJson(json['author'] as Map<String, dynamic>),
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );
}
