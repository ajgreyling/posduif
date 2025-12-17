import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class APIClient {
  final Dio _dio;
  String? _baseUrl;
  String? _deviceId;

  APIClient() : _dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      )) {
    _loadConfig();
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_deviceId != null) {
          options.headers['X-Device-ID'] = _deviceId;
        }
        return handler.next(options);
      },
    ));
  }

  Future<void> _loadConfig() async {
    debugPrint('[API_CLIENT] Loading configuration...');
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('api_base_url'); // No default - must be set during enrollment
    _deviceId = prefs.getString('device_id');
    debugPrint('[API_CLIENT] Loaded baseUrl: ${_baseUrl ?? "null"}');
    debugPrint('[API_CLIENT] Loaded deviceId: ${_deviceId ?? "null"}');
    if (_baseUrl != null) {
      _dio.options.baseUrl = _baseUrl!;
      debugPrint('[API_CLIENT] Set Dio baseUrl to: ${_baseUrl}');
    } else {
      debugPrint('[API_CLIENT] WARNING: No baseUrl set - API calls will fail');
    }
  }

  void setBaseUrl(String url) {
    _baseUrl = url;
    _dio.options.baseUrl = url;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('api_base_url', url);
    });
  }

  void setDeviceId(String deviceId) {
    _deviceId = deviceId;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('device_id', deviceId);
    });
  }

  /// Check if the API client is configured (enrolled)
  bool get isConfigured => _baseUrl != null && _deviceId != null;

  /// Ensure the client is configured before making API calls
  void _ensureConfigured() {
    debugPrint('[API_CLIENT] Checking configuration...');
    debugPrint('[API_CLIENT] isConfigured: $isConfigured');
    debugPrint('[API_CLIENT] _baseUrl: $_baseUrl');
    debugPrint('[API_CLIENT] _deviceId: $_deviceId');
    if (!isConfigured) {
      debugPrint('[API_CLIENT] ERROR: Not configured - throwing exception');
      throw Exception('App not enrolled. Please complete enrollment first.');
    }
    debugPrint('[API_CLIENT] Configuration check passed');
  }

  // Sync endpoints
  Future<Map<String, dynamic>> syncIncoming({int? limit}) async {
    debugPrint('[API_CLIENT] syncIncoming called');
    _ensureConfigured();
    final queryParams = limit != null ? {'limit': limit} : null;
    debugPrint('[API_CLIENT] Making GET request to: /api/sync/incoming');
    try {
      final response = await _dio.get('/api/sync/incoming', queryParameters: queryParams);
      debugPrint('[API_CLIENT] syncIncoming success');
      return response.data;
    } catch (e) {
      debugPrint('[API_CLIENT] syncIncoming error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> syncOutgoing(List<Map<String, dynamic>> messages) async {
    debugPrint('[API_CLIENT] syncOutgoing called');
    _ensureConfigured();
    debugPrint('[API_CLIENT] Making POST request to: /api/sync/outgoing');
    try {
      final response = await _dio.post(
        '/api/sync/outgoing',
        data: {'messages': messages},
      );
      debugPrint('[API_CLIENT] syncOutgoing success');
      return response.data;
    } catch (e) {
      debugPrint('[API_CLIENT] syncOutgoing error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getSyncStatus() async {
    debugPrint('[API_CLIENT] getSyncStatus called');
    _ensureConfigured();
    debugPrint('[API_CLIENT] Making GET request to: /api/sync/status');
    try {
      final response = await _dio.get('/api/sync/status');
      debugPrint('[API_CLIENT] getSyncStatus success');
      return response.data;
    } catch (e) {
      debugPrint('[API_CLIENT] getSyncStatus error: $e');
      rethrow;
    }
  }
}

