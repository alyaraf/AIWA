/// ChatController ChatMessageDto (GET/POST /bookings/{id}/chat).
class ChatMessageEntity {
  final String id;
  final int senderId;
  final String message;
  final bool removed;
  final DateTime createdAt;

  const ChatMessageEntity({
    required this.id,
    required this.senderId,
    required this.message,
    required this.removed,
    required this.createdAt,
  });

  factory ChatMessageEntity.fromJson(Map<String, dynamic> json) =>
      ChatMessageEntity(
        id: json['id'].toString(),
        senderId: (json['sender'] as Map<String, dynamic>?)?['id'] as int? ?? 0,
        message: json['message'] as String? ?? '',
        removed: json['removed'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
