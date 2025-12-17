import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnrollmentService {
  final Dio _dio;
  final SharedPreferences _prefs;

  EnrollmentService(this._dio, this._prefs);

  Future<Map<String, dynamic>> getEnrollmentDetails(String token) async {
    try {
      final response = await _dio.get('/api/enrollment/$token');
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> completeEnrollment({
    required String token,
    required String deviceId,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      final response = await _dio.post(
        '/api/enrollment/complete',
        data: {
          'token': token,
          'device_id': deviceId,
          'device_info': deviceInfo ?? {},
        },
      );
      
      // Store enrollment data
      await _prefs.setString('device_id', deviceId);
      await _prefs.setString('tenant_id', response.data['tenant_id']);
      await _prefs.setString('user_id', response.data['user_id']);
      
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAppInstructions(String deviceId) async {
    try {
      final response = await _dio.get(
        '/api/app-instructions',
        options: Options(
          headers: {'X-Device-ID': deviceId},
        ),
      );
      
      // Store app instructions
      await _prefs.setString('app_instructions', response.data.toString());
      await _prefs.setString('api_base_url', response.data['api_base_url']);
      
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  bool isEnrolled() {
    return _prefs.getString('device_id') != null;
  }

  String? getDeviceId() {
    return _prefs.getString('device_id');
  }

  String? getTenantId() {
    return _prefs.getString('tenant_id');
  }

  String? getApiBaseUrl() {
    return _prefs.getString('api_base_url');
  }
}

