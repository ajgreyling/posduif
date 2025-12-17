import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    print('[LOGIN] Login button clicked');
    
    if (!_formKey.currentState!.validate()) {
      print('[LOGIN] Form validation failed');
      return;
    }
    
    print('[LOGIN] Calling login with username: ${_usernameController.text.trim()}');
    
    final authNotifier = ref.read(authStateProvider.notifier);
    await authNotifier.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

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
        child: SizedBox(
          width: 400,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Posduif Web',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter username';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: authState.isLoading ? null : _handleLogin,
                        child: authState.isLoading
                            ? const CircularProgressIndicator()
                            : const Text('Login'),
                      ),
                    ),
                    if (authState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          authState.error!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

