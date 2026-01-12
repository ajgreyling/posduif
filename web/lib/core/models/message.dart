class Message {
  final String id;
  final String senderId;
  final String recipientId;
  final String content;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? syncedAt;
  final DateTime? readAt;

  Message({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.content,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.syncedAt,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      senderId: json['sender_id'],
      recipientId: json['recipient_id'],
      content: json['content'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'])
          : null,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'recipient_id': recipientId,
      'content': content,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    };
  }
}



