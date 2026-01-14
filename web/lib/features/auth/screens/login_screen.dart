import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import '../../../core/api/api_client.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String? _selectedUsername;
  List<String> _webUsernames = [];
  bool _isLoadingUsers = true;
  String? _usersError;

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  Future<void> _loadAvailableUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _usersError = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final users = await apiClient.getAvailableWebUsers();
      
      setState(() {
        _webUsernames = users
            .map((user) => user['username'] as String? ?? '')
            .where((username) => username.isNotEmpty)
            .toList();
        _isLoadingUsers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingUsers = false;
        if (e.toString().contains('500') || 
            e.toString().contains('Service Unavailable') ||
            e.toString().contains('Database connection')) {
          _usersError = 'Database connection unavailable. Please ensure the database is running.';
        } else if (e.toString().contains('connection') || 
                   e.toString().contains('Connection refused') ||
                   e.toString().contains('Failed host lookup')) {
          _usersError = 'Unable to connect to server. Please check if the web API is running.';
        } else {
          _usersError = 'Failed to load available users. Please try again.';
        }
      });
    }
  }

  Future<void> _selectUsername(String username) async {
    setState(() {
      _selectedUsername = username;
    });

    final authNotifier = ref.read(authStateProvider.notifier);
    await authNotifier.login(username, ''); // No password

    // Wait for the next frame to ensure state is updated
    if (mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
      final authState = ref.read(authStateProvider);
      print('[LOGIN] Login result - authenticated: ${authState.isAuthenticated}, error: ${authState.error}');
      
      if (authState.isAuthenticated) {
        print('[LOGIN] Navigating to /users');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            context.go('/users');
          }
        });
      } else if (authState.error != null) {
        print('[LOGIN] Showing error snackbar: ${authState.error}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authState.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    
    // Listen for auth state changes and navigate when authenticated
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next.isAuthenticated && (previous == null || !previous.isAuthenticated)) {
        print('[LOGIN] Auth state changed to authenticated, navigating to /users');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && context.mounted) {
            context.go('/users');
          }
        });
      }
    });

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_outline,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              const Text(
                'Choose your username',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              if (authState.error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    authState.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              if (_usersError != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _usersError!,
                        style: const TextStyle(color: Colors.orange),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _loadAvailableUsers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              if (_isLoadingUsers)
                const CircularProgressIndicator()
              else if (_webUsernames.isEmpty && _usersError == null)
                const Text(
                  'No users available. Please contact administrator.',
                  style: TextStyle(color: Colors.grey),
                )
              else if (authState.isLoading)
                const CircularProgressIndicator()
              else
                ..._webUsernames.map((username) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: SizedBox(
                        width: 400,
                        child: ElevatedButton(
                          onPressed: () => _selectUsername(username),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            username,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

