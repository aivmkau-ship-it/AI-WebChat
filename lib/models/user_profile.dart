class UserProfile {
  const UserProfile({
    required this.userId,
    required this.phone,
    required this.nickname,
  });

  final int userId;
  final String phone;
  final String nickname;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'phone': phone,
        'nickname': nickname,
      };

  static UserProfile? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final phone = json['phone'] as String?;
    final nickname = json['nickname'] as String?;
    if (phone == null || nickname == null) return null;
    final uid = json['userId'] as int? ?? json['id'] as int?;
    if (uid == null) return null;
    return UserProfile(userId: uid, phone: phone, nickname: nickname);
  }
}
