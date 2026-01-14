import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class APIClient {
  final Dio _dio;
  final String baseUrl;
  String? _userId;

  APIClient({required this.baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_userId != null) {
          options.headers['X-User-ID'] = _userId!;
        }
        return handler.next(options);
      },
    ));

    _loadUserId();
  }

  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('current_user_id');
  }

  void setUserId(String userId) {
    _userId = userId;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('current_user_id', userId);
    });
  }

  void clearUserId() {
    _userId = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('current_user_id');
    });
  }

  String? get userId => _userId;

  // Authentication (username only, no password)
  Future<Map<String, dynamic>> login(String username) async {
    try {
      final response = await _dio.post(
        '/api/auth/login',
        data: {'username': username},
      );
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // Get available web users for login screen (public endpoint)
  Future<List<dynamic>> getAvailableWebUsers() async {
    try {
      final response = await _dio.get('/api/auth/available-users');
      // Handle both array response and object with 'users' field
      if (response.data is List) {
        return response.data as List<dynamic>;
      } else if (response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        if (data.containsKey('users')) {
          return data['users'] as List<dynamic>;
        }
        return [];
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  // Users
  Future<List<dynamic>> getUsers({String? filter, bool? status}) async {
    final queryParams = <String, dynamic>{};
    if (filter != null) queryParams['filter'] = filter;
    if (status != null) queryParams['status'] = status.toString();

    final response = await _dio.get('/api/users', queryParameters: queryParams);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> getUser(String id) async {
    final response = await _dio.get('/api/users/$id');
    return response.data;
  }

  // Enrollment
  Future<Map<String, dynamic>> createEnrollment() async {
    final response = await _dio.post('/api/enrollment/create');
    return response.data;
  }

  Future<Map<String, dynamic>> getEnrollmentStatus(String token) async {
    final response = await _dio.get('/api/enrollment/$token');
    return response.data;
  }

  // Messages
  Future<Map<String, dynamic>> sendMessage(
      String recipientId, String content) async {
    final response = await _dio.post(
      '/api/messages',
      data: {'recipient_id': recipientId, 'content': content},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> getMessages({
    String? recipientId,
    String? status,
    int? limit,
    int? offset,
  }) async {
    final queryParams = <String, dynamic>{};
    if (recipientId != null) queryParams['recipient_id'] = recipientId;
    if (status != null) queryParams['status'] = status;
    if (limit != null) queryParams['limit'] = limit;
    if (offset != null) queryParams['offset'] = offset;

    final response =
        await _dio.get('/api/messages', queryParameters: queryParams);
    return response.data as List<dynamic>;
  }

  Future<int> getUnreadCount() async {
    final response = await _dio.get('/api/messages/unread-count');
    return response.data['unread_count'] as int;
  }

  Future<Map<String, dynamic>> getMessage(String id) async {
    final response = await _dio.get('/api/messages/$id');
    return response.data;
  }

  Future<Map<String, dynamic>> markMessageAsRead(String id) async {
    final response = await _dio.put('/api/messages/$id/read');
    return response.data;
  }
}

