import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/database.dart';
import '../api/api_client.dart';

class SyncService {
  final AppDatabase _database;
  final APIClient _apiClient;
  final Connectivity _connectivity;

  SyncService(this._database, this._apiClient, this._connectivity);

  Future<void> performSync() async {
    // Check if API client is configured (enrolled)
    if (!_apiClient.isConfigured) {
      return; // No sync if not enrolled
    }

    // Check connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return; // No sync when offline
    }

    // Sync incoming messages
    await _syncIncoming();

    // Sync outgoing messages
    await _syncOutgoing();
  }

  Future<void> _syncIncoming() async {
    try {
      final response = await _apiClient.syncIncoming();
      final messages = response['messages'] as List<dynamic>? ?? [];
      final users = response['users'] as List<dynamic>? ?? [];

      // Sync messages
      for (final msgData in messages) {
        final message = Message(
          id: msgData['id'],
          senderId: msgData['sender_id'],
          recipientId: msgData['recipient_id'],
          content: msgData['content'],
          status: 'synced',
          createdAt: DateTime.parse(msgData['created_at']),
          updatedAt: DateTime.parse(msgData['updated_at']),
          syncedAt: DateTime.now(),
        );
        await _database.insertMessage(message);
      }

      // Sync users with last_message_sent (last-write-wins)
      if (users.isNotEmpty) {
        final usersList = users.map((userData) {
          final remoteUpdatedAt = DateTime.parse(userData['updated_at']);
          return User(
            id: userData['id'],
            username: userData['username'],
            userType: userData['user_type'],
            deviceId: userData['device_id'],
            onlineStatus: userData['online_status'] ?? false,
            lastSeen: userData['last_seen'] != null 
                ? DateTime.parse(userData['last_seen']) 
                : null,
            lastMessageSent: userData['last_message_sent'],
            createdAt: DateTime.parse(userData['created_at']),
            updatedAt: remoteUpdatedAt,
          );
        }).toList();
        await _database.insertUsers(usersList);
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _syncOutgoing() async {
    try {
      final pendingMessages = await _database.getPendingMessages();
      
      if (pendingMessages.isEmpty) return;

      final messagesData = pendingMessages.map((msg) => {
        'id': msg.id,
        'sender_id': msg.senderId,
        'recipient_id': msg.recipientId,
        'content': msg.content,
        'status': msg.status,
        'created_at': msg.createdAt.toIso8601String(),
        'updated_at': msg.updatedAt.toIso8601String(),
      }).toList();

      final response = await _apiClient.syncOutgoing(messagesData);
      
      final syncedCount = response['synced_count'] as int? ?? 0;
      if (syncedCount > 0) {
        // Update message status to synced
        for (final msg in pendingMessages.take(syncedCount)) {
          await _database.updateMessageStatus(msg.id, 'synced');
        }
      }
    } catch (e) {
      // Handle error
    }
  }
}

