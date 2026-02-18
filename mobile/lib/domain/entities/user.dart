class User {
  final String id;
  final String email;
  final String nickname;
  final String? avatarUrl;
  final int chipBalance;

  const User({
    required this.id,
    required this.email,
    required this.nickname,
    this.avatarUrl,
    required this.chipBalance,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      nickname: json['nickname'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      chipBalance: json['chipBalance'] as int? ?? 10000,
    );
  }
}
