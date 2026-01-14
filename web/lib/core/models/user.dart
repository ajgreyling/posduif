class User {
  final String id;
  final String username;
  final String userType;
  final String? deviceId;
  final bool onlineStatus;
  final DateTime? lastSeen;
  final String? lastMessageSent;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    required this.userType,
    this.deviceId,
    required this.onlineStatus,
    this.lastSeen,
    this.lastMessageSent,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      userType: json['user_type'],
      deviceId: json['device_id'],
      onlineStatus: json['online_status'] ?? false,
      lastSeen: json['last_seen'] != null
          ? DateTime.parse(json['last_seen'])
          : null,
      lastMessageSent: json['last_message_sent'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'user_type': userType,
      'device_id': deviceId,
      'online_status': onlineStatus,
      'last_seen': lastSeen?.toIso8601String(),
      'last_message_sent': lastMessageSent,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}



