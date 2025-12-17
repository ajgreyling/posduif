import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemoteWidgetLoader {
  final Dio _dio;
  final SharedPreferences _prefs;

  RemoteWidgetLoader(this._dio, this._prefs);

  Future<Map<String, dynamic>> loadWidget(String widgetUrl) async {
    try {
      final response = await _dio.get(widgetUrl);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> getAvailableWidgets() async {
    final apiBaseUrl = _prefs.getString('api_base_url');
    if (apiBaseUrl == null) return [];

    // Load app instructions to get widget list
    final deviceId = _prefs.getString('device_id');
    if (deviceId == null) return [];

    try {
      final response = await _dio.get(
        '$apiBaseUrl/api/app-instructions',
        options: Options(
          headers: {'X-Device-ID': deviceId},
        ),
      );

      final widgets = response.data['widgets'] as Map<String, dynamic>;
      return widgets.keys.toList();
    } catch (e) {
      return [];
    }
  }

  Widget renderWidget(Map<String, dynamic> widgetData) {
    // Basic widget rendering - in production, use flutter_remote_widgets
    final type = widgetData['type'] as String? ?? 'container';
    
    switch (type) {
      case 'text':
        return Text(widgetData['text'] ?? '');
      case 'container':
        return Container(
          child: widgetData['child'] != null
              ? renderWidget(widgetData['child'])
              : null,
        );
      default:
        return const SizedBox();
    }
  }
}

