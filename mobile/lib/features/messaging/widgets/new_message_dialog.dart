import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api/api_client.dart';
import '../../../core/providers/providers.dart';

class NewMessageDialog extends ConsumerStatefulWidget {
  const NewMessageDialog({super.key});

  @override
  ConsumerState<NewMessageDialog> createState() => _NewMessageDialogState();
}

class _NewMessageDialogState extends ConsumerState<NewMessageDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
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
      _currentUserId = prefs.getString('user_id');
    });
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final users = await apiClient.getUsers();
      
      // Filter out current user
      final filtered = users.where((user) {
        final userId = (user as Map<String, dynamic>)['id'] as String?;
        return userId != _currentUserId;
      }).toList();

      setState(() {
        _allUsers = filtered.cast<Map<String, dynamic>>();
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
          final username = (user['username'] as String? ?? '').toLowerCase();
          return username.contains(query);
        }).toList();
      }
    });
  }

  void _selectUser(Map<String, dynamic> user) {
    final userId = user['id'] as String;
    Navigator.of(context).pop();
    context.push('/chat/$userId');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
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
                                final username = user['username'] as String? ?? 'Unknown';
                                final userType = user['user_type'] as String? ?? '';
                                final onlineStatus = user['online_status'] as bool? ?? false;
                                
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: onlineStatus
                                        ? Colors.green
                                        : Colors.grey,
                                    child: Text(
                                      username.isNotEmpty
                                          ? username[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  title: Text(username),
                                  subtitle: Text(userType),
                                  trailing: onlineStatus
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
