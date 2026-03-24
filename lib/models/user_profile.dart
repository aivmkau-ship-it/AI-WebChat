class UserProfile {
  const UserProfile({
    required this.phone,
    required this.nickname,
  });

  final String phone;
  final String nickname;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'nickname': nickname,
      };

  static UserProfile? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final phone = json['phone'] as String?;
    final nickname = json['nickname'] as String?;
    if (phone == null || nickname == null) return null;
    return UserProfile(phone: phone, nickname: nickname);
  }
}
