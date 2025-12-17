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
    Map<String, dynamic>? deviceInfo,
  }) async {
    debugPrint('[ENROLLMENT] completeEnrollment called');
    debugPrint('[ENROLLMENT] token: $token');
    debugPrint('[ENROLLMENT] deviceId: $deviceId');
    try {
      final url = '/api/enrollment/complete';
      debugPrint('[ENROLLMENT] Making POST request to: $url');
      debugPrint('[ENROLLMENT] Dio baseUrl: ${_dio.options.baseUrl}');
      final response = await _dio.post(
        url,
        data: {
          'token': token,
          'device_id': deviceId,
          'device_info': deviceInfo ?? {},
        },
      );
      
      debugPrint('[ENROLLMENT] Enrollment completed successfully');
      debugPrint('[ENROLLMENT] Response data: ${response.data}');
      
      // Store enrollment data
      await _prefs.setString('device_id', deviceId);
      await _prefs.setString('tenant_id', response.data['tenant_id']);
      await _prefs.setString('user_id', response.data['user_id']);
      debugPrint('[ENROLLMENT] Stored device_id: $deviceId');
      debugPrint('[ENROLLMENT] Stored tenant_id: ${response.data['tenant_id']}');
      debugPrint('[ENROLLMENT] Stored user_id: ${response.data['user_id']}');
      
      return response.data;
    } catch (e) {
      debugPrint('[ENROLLMENT] Error completing enrollment: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAppInstructions(String deviceId) async {
    debugPrint('[ENROLLMENT] getAppInstructions called');
    debugPrint('[ENROLLMENT] deviceId: $deviceId');
    try {
      final url = '/api/app-instructions';
      debugPrint('[ENROLLMENT] Making GET request to: $url');
      debugPrint('[ENROLLMENT] Dio baseUrl: ${_dio.options.baseUrl}');
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'X-Device-ID': deviceId},
        ),
      );
      
      debugPrint('[ENROLLMENT] App instructions retrieved successfully');
      debugPrint('[ENROLLMENT] Response status: ${response.statusCode}');
      debugPrint('[ENROLLMENT] Response api_base_url: ${response.data['api_base_url']}');
      debugPrint('[ENROLLMENT] Response widgets: ${response.data['widgets']?.keys}');
      
      // Store app instructions as JSON string
      final instructionsJson = response.data.toString();
      await _prefs.setString('app_instructions', instructionsJson);
      debugPrint('[ENROLLMENT] Stored app instructions');
      
      // Store app_instructions_url if provided in response
      if (response.data['app_instructions_url'] != null) {
        final appInstructionsUrl = response.data['app_instructions_url'] as String;
        // Only save if it's not localhost
        if (!appInstructionsUrl.contains('localhost') && !appInstructionsUrl.contains('127.0.0.1')) {
          await _prefs.setString('app_instructions_url', appInstructionsUrl);
          debugPrint('[ENROLLMENT] Stored app_instructions_url: $appInstructionsUrl');
        } else {
          debugPrint('[ENROLLMENT] Skipped storing app_instructions_url (contains localhost)');
        }
      }
      
      // Don't overwrite api_base_url if it's already set - the one from QR code is correct
      // The backend returns localhost which won't work from mobile device
      // Keep using the API base URL extracted from the enrollment QR code
      final currentApiBaseUrl = _prefs.getString('api_base_url');
      debugPrint('[ENROLLMENT] Current api_base_url: $currentApiBaseUrl');
      debugPrint('[ENROLLMENT] Backend returned api_base_url: ${response.data['api_base_url']}');
      if (currentApiBaseUrl == null) {
        // Only set if not already set (shouldn't happen, but be safe)
        final backendUrl = response.data['api_base_url'] as String;
        // Only save if it's not localhost
        if (!backendUrl.contains('localhost') && !backendUrl.contains('127.0.0.1')) {
          await _prefs.setString('api_base_url', backendUrl);
          debugPrint('[ENROLLMENT] Set api_base_url from backend response: $backendUrl');
        } else {
          debugPrint('[ENROLLMENT] Skipped setting api_base_url (backend returned localhost)');
        }
      } else {
        debugPrint('[ENROLLMENT] Keeping existing api_base_url (not overwriting)');
      }
      
      return response.data;
    } catch (e) {
      debugPrint('[ENROLLMENT] Error getting app instructions: $e');
      if (e is DioException) {
        debugPrint('[ENROLLMENT] DioException type: ${e.type}');
        debugPrint('[ENROLLMENT] DioException response: ${e.response?.statusCode}');
        debugPrint('[ENROLLMENT] DioException message: ${e.message}');
      }
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

