import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';
import '../widgets/conversation_tile.dart';
import '../widgets/new_message_dialog.dart';

class ConversationListScreen extends ConsumerWidget {
  const ConversationListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final database = ref.watch(databaseProvider);
    final currentUserIdAsync = ref.watch(userIdProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () {
              // Trigger sync
              ref.read(syncServiceProvider).performSync();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const NewMessageDialog(),
          );
        },
        child: const Icon(Icons.message),
      ),
      body: currentUserIdAsync.when(
        data: (currentUserId) {
          return StreamBuilder<List<User>>(
            stream: database.watchAllUsers(),
            builder: (context, usersSnapshot) {
              if (!usersSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final users = usersSnapshot.data!;
              // Filter out current user
              final otherUsers = users.where((u) => u.id != currentUserId).toList();

              if (otherUsers.isEmpty) {
                return const Center(
                  child: Text('No conversations yet'),
                );
              }

              return ListView.builder(
                itemCount: otherUsers.length,
                itemBuilder: (context, index) {
                  final user = otherUsers[index];
                  return ConversationTile(
                    user: user,
                    currentUserId: currentUserId ?? '',
                    onTap: () {
                      context.push('/chat/${user.id}');
                    },
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
