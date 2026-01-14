import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers.dart';
import '../../../core/api/api_client.dart';
import '../../../core/models/user.dart';

class NewMessageDialog extends ConsumerStatefulWidget {
  const NewMessageDialog({super.key});

  @override
  ConsumerState<NewMessageDialog> createState() => _NewMessageDialogState();
}

class _NewMessageDialogState extends ConsumerState<NewMessageDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _allUsers = [];
  List<User> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUserId();
    _loadUsers();
    _searchController.addListener(_filterUsers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString('current_user_id');
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final usersData = await apiClient.getUsers();
      
      // Convert to User objects and filter out current user
      final users = usersData.map((json) => User.fromJson(json as Map<String, dynamic>)).toList();
      final filtered = users.where((user) => user.id != _currentUserId).toList();

      setState(() {
        _allUsers = filtered;
        _filteredUsers = _allUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterUsers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = _allUsers;
      } else {
        _filteredUsers = _allUsers.where((user) {
          return user.username.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _selectUser(User user) {
    Navigator.of(context).pop();
    context.go('/conversation/${user.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'New Message',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Search field
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                autofocus: true,
              ),
            ),
            // User list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Error loading users',
                                style: TextStyle(color: Colors.red[700]),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _loadUsers,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : _filteredUsers.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.isEmpty
                                    ? 'No users found'
                                    : 'No users match your search',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = _filteredUsers[index];
                                
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: user.onlineStatus
                                        ? Colors.green
                                        : Colors.grey,
                                    child: Text(
                                      user.username.isNotEmpty
                                          ? user.username[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(user.username),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(user.userType),
                                      if (user.lastMessageSent != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Last message: ${user.lastMessageSent}',
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
                                      ? const Icon(
                                          Icons.circle,
                                          size: 12,
                                          color: Colors.green,
                                        )
                                      : null,
                                  onTap: () => _selectUser(user),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
