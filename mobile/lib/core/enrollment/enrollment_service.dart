import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EnrollmentService {
  final Dio _dio;
  final SharedPreferences _prefs;

  EnrollmentService(this._dio, this._prefs);

  Future<Map<String, dynamic>> getEnrollmentDetails(String token) async {
    debugPrint('[ENROLLMENT] getEnrollmentDetails called for token: $token');
    try {
      final url = '/api/enrollment/$token';
      debugPrint('[ENROLLMENT] Making GET request to: $url');
      debugPrint('[ENROLLMENT] Dio baseUrl: ${_dio.options.baseUrl}');
      final response = await _dio.get(url);
      debugPrint('[ENROLLMENT] Enrollment details retrieved successfully');
      return response.data;
    } catch (e) {
      debugPrint('[ENROLLMENT] Error getting enrollment details: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> completeEnrollment({
    required String token,
    required String deviceId,
    required String username,
    Map<String, dynamic>? deviceInfo,
  }) async {
    debugPrint('[ENROLLMENT] completeEnrollment called');
    debugPrint('[ENROLLMENT] token: $token');
    debugPrint('[ENROLLMENT] deviceId: $deviceId');
    debugPrint('[ENROLLMENT] username: $username');
    try {
      final url = '/api/enrollment/complete';
      debugPrint('[ENROLLMENT] Making POST request to: $url');
      debugPrint('[ENROLLMENT] Dio baseUrl: ${_dio.options.baseUrl}');
      final response = await _dio.post(
        url,
        data: {
          'token': token,
          'device_id': deviceId,
          'username': username,
          'device_info': deviceInfo ?? {},
        },
      );
      
      debugPrint('[ENROLLMENT] Enrollment completed successfully');
      debugPrint('[ENROLLMENT] Response data: ${response.data}');
      
      // Store enrollment data
      await _prefs.setString('device_id', deviceId);
      await _prefs.setString('tenant_id', response.data['tenant_id']);
      await _prefs.setString('user_id', response.data['user_id']);
      await _prefs.setString('username', username);
      debugPrint('[ENROLLMENT] Stored device_id: $deviceId');
      debugPrint('[ENROLLMENT] Stored tenant_id: ${response.data['tenant_id']}');
      debugPrint('[ENROLLMENT] Stored user_id: ${response.data['user_id']}');
      debugPrint('[ENROLLMENT] Stored username: $username');
      
      return response.data;
    } catch (e) {
      debugPrint('[ENROLLMENT] Error completing enrollment: $e');
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

  /// Clear all enrollment-related data from SharedPreferences
  /// This is useful for debugging (Hot Restart) or resetting enrollment
  static Future<void> clearEnrollmentData() async {
    debugPrint('[ENROLLMENT] Clearing all enrollment data...');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('api_base_url');
      await prefs.remove('device_id');
      await prefs.remove('tenant_id');
      await prefs.remove('user_id');
      await prefs.remove('username');
      debugPrint('[ENROLLMENT] All enrollment data cleared successfully');
    } catch (e) {
      debugPrint('[ENROLLMENT] Error clearing enrollment data: $e');
      rethrow;
    }
  }
}

