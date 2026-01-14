import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/user.dart';
import '../widgets/new_message_dialog.dart';

class UserSelectionScreen extends ConsumerStatefulWidget {
  const UserSelectionScreen({super.key});

  @override
  ConsumerState<UserSelectionScreen> createState() => _UserSelectionScreenState();
}

class _UserSelectionScreenState extends ConsumerState<UserSelectionScreen> {
  List<User> _users = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final usersData = await apiClient.getUsers();
      setState(() {
        _users = usersData.map((json) => User.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select User'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => context.go('/enroll'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const NewMessageDialog(),
          );
        },
        icon: const Icon(Icons.message),
        label: const Text('New Message'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _users.isEmpty
                  ? const Center(child: Text('No users found'))
                  : ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: user.onlineStatus
                                ? Colors.green
                                : Colors.grey,
                            child: Text(user.username[0].toUpperCase()),
                          ),
                          title: Text(user.username),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.userType),
                              if (user.lastMessageSent != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Last message sent: ${user.lastMessageSent}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          trailing: user.onlineStatus
                              ? const Icon(Icons.circle, size: 12, color: Colors.green)
                              : null,
                          onTap: () {
                            context.go('/conversation/${user.id}');
                          },
                        );
                      },
                    ),
    );
  }
}



