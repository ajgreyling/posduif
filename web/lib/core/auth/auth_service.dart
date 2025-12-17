import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

// Extension to access private token
extension APIClientExtension on APIClient {
  String? get token => _token;
}

class AuthService {
  final APIClient apiClient;
  Map<String, dynamic>? _currentUser;

  AuthService(this.apiClient);

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final response = await apiClient.login(username, password);
      final token = response['token'] as String;
      final user = response['user'] as Map<String, dynamic>;

      apiClient.setToken(token);
      _currentUser = user;

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    apiClient.clearToken();
    _currentUser = null;
  }

  bool isAuthenticated() {
    return _currentUser != null || apiClient.token != null;
  }

  Map<String, dynamic>? getCurrentUser() {
    return _currentUser;
  }

  String? getToken() {
    return apiClient.token;
  }

  Future<void> loadStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null) {
      apiClient.setToken(token);
      // TODO: Load user from token or API
      final userJson = prefs.getString('current_user');
      if (userJson != null) {
        // Parse user from JSON if stored
      }
    }
  }
}

