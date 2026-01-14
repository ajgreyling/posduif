import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';
import '../../../core/sync/sync_service.dart';
import '../widgets/message_bubble.dart';

Future<String?> getCurrentUserId() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('user_id');
}

class ChatScreen extends ConsumerStatefulWidget {
  final String recipientId;

  const ChatScreen({
    super.key,
    required this.recipientId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    final currentUserId = await getCurrentUserId();
    if (currentUserId == null) return;

    final database = ref.read(databaseProvider);
    final syncService = ref.read(syncServiceProvider);

    // Create message
    final message = Message(
      id: const Uuid().v4(),
      senderId: currentUserId,
      recipientId: widget.recipientId,
      content: content,
      status: 'pending_sync',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Save to local database
    await database.insertMessage(message);

    // Update sender's last_message_sent
    final sender = await database.getUserById(currentUserId);
    if (sender != null) {
      final updatedSender = User(
        id: sender.id,
        username: sender.username,
        userType: sender.userType,
        deviceId: sender.deviceId,
        onlineStatus: sender.onlineStatus,
        lastSeen: sender.lastSeen,
        lastMessageSent: content,
        createdAt: sender.createdAt,
        updatedAt: DateTime.now(),
      );
      await database.updateUser(updatedSender);
    }

    // Clear input
    _messageController.clear();

    // Trigger sync
    syncService.performSync();

    // Scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final database = ref.watch(databaseProvider);
    final currentUserIdAsync = ref.watch(userIdProvider);

    return currentUserIdAsync.when(
      data: (currentUserId) {
        return Scaffold(
          appBar: AppBar(
            title: FutureBuilder<User?>(
              future: database.getUserById(widget.recipientId),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return Text(snapshot.data!.username);
                }
                return const Text('Chat');
              },
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<Message>>(
                  stream: database.watchMessagesForConversation(
                    widget.recipientId,
                    currentUserId ?? '',
                  ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;

                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet'),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    return MessageBubble(
                      message: message,
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        body: Center(child: Text('Error: $err')),
      ),
    );
  }
}
