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

