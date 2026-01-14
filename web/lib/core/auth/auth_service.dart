import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';

class AuthService {
  final APIClient apiClient;
  Map<String, dynamic>? _currentUser;

  AuthService(this.apiClient);

  Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      // No password needed - username only
      final response = await apiClient.login(username);
      final user = response as Map<String, dynamic>;

      // Store user ID in header for subsequent requests
      apiClient.setUserId(user['user_id'] as String);
      _currentUser = user;

      // Store user info
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', user['user_id'] as String);
      await prefs.setString('current_username', user['username'] as String);

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    apiClient.clearUserId();
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    await prefs.remove('current_username');
  }

  bool isAuthenticated() {
    return _currentUser != null || apiClient.userId != null;
  }

  Map<String, dynamic>? getCurrentUser() {
    return _currentUser;
  }

  String? getToken() {
    // Web API uses user ID, not token
    return apiClient.userId;
  }

  Future<void> loadStoredAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('current_user_id');
    if (userId != null) {
      apiClient.setUserId(userId);
      final username = prefs.getString('current_username');
      if (username != null) {
        _currentUser = {
          'user_id': userId,
          'username': username,
        };
      }
    }
  }
}

