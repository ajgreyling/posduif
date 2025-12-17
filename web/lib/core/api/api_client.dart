import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class APIClient {
  final Dio _dio;
  final String baseUrl;
  String? _token;

  APIClient({required this.baseUrl})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401) {
          _token = null;
        }
        return handler.next(error);
      },
    ));

    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  void setToken(String token) {
    _token = token;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('auth_token', token);
    });
  }

  void clearToken() {
    _token = null;
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('auth_token');
    });
  }

  // Authentication
  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _dio.post(
      '/api/auth/login',
      data: {'username': username, 'password': password},
    );
    return response.data;
  }

  // Users
  Future<List<dynamic>> getUsers({String? filter, bool? status}) async {
    final queryParams = <String, dynamic>{};
    if (filter != null) queryParams['filter'] = filter;
    if (status != null) queryParams['status'] = status.toString();

    final response = await _dio.get('/api/users', queryParameters: queryParams);
    return response.data['users'] as List<dynamic>;
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
    return response.data;
  }

  Future<Map<String, dynamic>> getMessages({
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
    return response.data;
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

