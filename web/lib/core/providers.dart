import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api/api_client.dart';
import 'auth/auth_service.dart';

// API Client Provider
final apiClientProvider = Provider<APIClient>((ref) {
  return APIClient(baseUrl: 'http://localhost:8080');
});

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(apiClientProvider));
});

// Auth State Provider
final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService authService;

  AuthNotifier(this.authService) : super(AuthState.initial()) {
    _loadAuth();
  }

  Future<void> _loadAuth() async {
    await authService.loadStoredAuth();
    if (authService.isAuthenticated()) {
      state = AuthState.authenticated(authService.getCurrentUser());
    }
  }

  Future<void> login(String username, String password) async {
    state = AuthState.loading();
    try {
      final response = await authService.login(username, password);
      state = AuthState.authenticated(response['user']);
    } catch (e) {
      state = AuthState.error(e.toString());
    }
  }

  Future<void> logout() async {
    await authService.logout();
    state = AuthState.initial();
  }
}

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final Map<String, dynamic>? user;
  final String? error;

  AuthState({
    required this.isLoading,
    required this.isAuthenticated,
    this.user,
    this.error,
  });

  factory AuthState.initial() {
    return AuthState(
      isLoading: false,
      isAuthenticated: false,
    );
  }

  factory AuthState.loading() {
    return AuthState(
      isLoading: true,
      isAuthenticated: false,
    );
  }

  factory AuthState.authenticated(Map<String, dynamic>? user) {
    return AuthState(
      isLoading: false,
      isAuthenticated: true,
      user: user,
    );
  }

  factory AuthState.error(String error) {
    return AuthState(
      isLoading: false,
      isAuthenticated: false,
      error: error,
    );
  }
}

