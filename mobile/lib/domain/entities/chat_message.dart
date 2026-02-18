/// Domain entity representing a single chat message in a poker room.
class ChatMessage {
  final String id;
  final String userId;
  final String nickname;
  final String? avatarUrl;
  final String content;
  final String messageType; // TEXT, EMOJI, SYSTEM
  final String? handId;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.content,
    required this.messageType,
    this.handId,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? json['messageId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      nickname: json['nickname'] as String? ?? 'Unknown',
      avatarUrl: json['avatarUrl'] as String?,
      content: json['content'] as String? ?? json['message'] as String? ?? '',
      messageType: json['messageType'] as String? ?? json['type'] as String? ?? 'TEXT',
      handId: json['handId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Whether this is a system-generated message (e.g. "Player X joined").
  bool get isSystem => messageType == 'SYSTEM';

  /// Whether this is an emoji-only message.
  bool get isEmoji => messageType == 'EMOJI';
}
