import 'package:dio/dio.dart';
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
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = prefs.getString('api_base_url') ?? 'http://localhost:8080';
    _deviceId = prefs.getString('device_id');
    _dio.options.baseUrl = _baseUrl!;
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

  // Sync endpoints
  Future<Map<String, dynamic>> syncIncoming({int? limit}) async {
    final queryParams = limit != null ? {'limit': limit} : null;
    final response = await _dio.get('/api/sync/incoming', queryParameters: queryParams);
    return response.data;
  }

  Future<Map<String, dynamic>> syncOutgoing(List<Map<String, dynamic>> messages) async {
    final response = await _dio.post(
      '/api/sync/outgoing',
      data: {'messages': messages},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getSyncStatus() async {
    final response = await _dio.get('/api/sync/status');
    return response.data;
  }
}

