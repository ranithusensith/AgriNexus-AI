/// Public identity of another user (no email/phone), as returned by the
/// Module 3 endpoints.
class UserBrief {
  final String id;
  final String fullName;
  final String role;

  const UserBrief({required this.id, required this.fullName, required this.role});

  factory UserBrief.fromJson(Map<String, dynamic> json) => UserBrief(
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
      );

  String get initial => fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
}
