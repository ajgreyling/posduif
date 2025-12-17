import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemoteWidgetLoader {
  final Dio _dio;
  final SharedPreferences _prefs;
  final WidgetRef? _ref;

  RemoteWidgetLoader(this._dio, this._prefs, [this._ref]);

  /// Check if the app is enrolled (has device_id and api_base_url)
  bool _isEnrolled() {
    final deviceId = _prefs.getString('device_id');
    final apiBaseUrl = _prefs.getString('api_base_url');
    return deviceId != null && apiBaseUrl != null;
  }

  /// Ensure enrollment before making API calls
  void _ensureEnrolled() {
    debugPrint('[WIDGET_LOADER] Checking enrollment...');
    final isEnrolled = _isEnrolled();
    debugPrint('[WIDGET_LOADER] Enrollment status: $isEnrolled');
    if (!isEnrolled) {
      debugPrint('[WIDGET_LOADER] ERROR: Not enrolled');
      throw Exception('App not enrolled. Please complete enrollment first.');
    }
    debugPrint('[WIDGET_LOADER] Enrollment check passed');
  }

  Future<Map<String, dynamic>> loadWidget(String widgetUrl) async {
    debugPrint('[WIDGET_LOADER] loadWidget called with URL: $widgetUrl');
    _ensureEnrolled();
    try {
      debugPrint('[WIDGET_LOADER] Making GET request to widget URL');
      final response = await _dio.get(widgetUrl);
      debugPrint('[WIDGET_LOADER] Widget loaded successfully');
      return response.data;
    } catch (e) {
      debugPrint('[WIDGET_LOADER] Error loading widget: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAppInstructions() async {
    debugPrint('[WIDGET_LOADER] getAppInstructions called');
    _ensureEnrolled();
    
    final apiBaseUrl = _prefs.getString('api_base_url');
    if (apiBaseUrl == null) {
      debugPrint('[WIDGET_LOADER] ERROR: API base URL not found');
      throw Exception('API base URL not found. Please re-enroll.');
    }
    debugPrint('[WIDGET_LOADER] API base URL: $apiBaseUrl');

    final deviceId = _prefs.getString('device_id');
    if (deviceId == null) {
      debugPrint('[WIDGET_LOADER] ERROR: Device ID not found');
      throw Exception('Device ID not found. Please re-enroll.');
    }
    debugPrint('[WIDGET_LOADER] Device ID: $deviceId');

    final url = '$apiBaseUrl/api/app-instructions';
    debugPrint('[WIDGET_LOADER] Making GET request to: $url');
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'X-Device-ID': deviceId},
        ),
      );
      debugPrint('[WIDGET_LOADER] App instructions retrieved successfully');
      return response.data;
    } catch (e) {
      debugPrint('[WIDGET_LOADER] Error getting app instructions: $e');
      rethrow;
    }
  }

  Future<List<String>> getAvailableWidgets() async {
    try {
      final instructions = await getAppInstructions();
      final widgets = instructions['widgets'] as Map<String, dynamic>;
      return widgets.keys.toList();
    } catch (e) {
      return [];
    }
  }

  Widget renderWidget(Map<String, dynamic> widgetData, {WidgetRef? ref}) {
    final type = widgetData['type'] as String? ?? '';
    final widget = widgetData['widget'] as String? ?? '';
    
    // Use ref parameter if provided, otherwise fall back to instance ref
    final widgetRef = ref ?? _ref;
    
    // For now, return a placeholder widget
    // In production, this would use Flutter Remote Widgets to render the actual widget
    switch (type) {
      case 'inbox_screen':
        return _buildInboxPlaceholder(widgetRef);
      case 'compose_screen':
        return _buildComposePlaceholder(widgetRef);
      case 'message_detail_screen':
        final messageId = widgetData['message_id'] as String?;
        return _buildMessageDetailPlaceholder(messageId, widgetRef);
      default:
        return Center(
          child: Text('Unknown widget type: $type'),
        );
    }
  }

  Widget _buildInboxPlaceholder(WidgetRef? ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: const Center(
        child: Text('Inbox widget will be loaded here'),
      ),
    );
  }

  Widget _buildComposePlaceholder(WidgetRef? ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compose Message'),
      ),
      body: const Center(
        child: Text('Compose widget will be loaded here'),
      ),
    );
  }

  Widget _buildMessageDetailPlaceholder(String? messageId, WidgetRef? ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Detail'),
      ),
      body: Center(
        child: Text('Message detail widget will be loaded here${messageId != null ? " (ID: $messageId)" : ""}'),
      ),
    );
  }

  Future<Widget> loadAndRenderWidget(String widgetName, {WidgetRef? ref}) async {
    debugPrint('[WIDGET_LOADER] loadAndRenderWidget called for: $widgetName');
    try {
      _ensureEnrolled();
      
      debugPrint('[WIDGET_LOADER] Fetching app instructions...');
      final instructions = await getAppInstructions();
      final widgets = instructions['widgets'] as Map<String, dynamic>;
      debugPrint('[WIDGET_LOADER] Available widgets: ${widgets.keys.toList()}');
      
      final widgetConfig = widgets[widgetName] as Map<String, dynamic>?;
      
      if (widgetConfig == null) {
        debugPrint('[WIDGET_LOADER] ERROR: Widget $widgetName not found in instructions');
        return Center(child: Text('Widget $widgetName not found'));
      }
      
      var widgetUrl = widgetConfig['url'] as String;
      debugPrint('[WIDGET_LOADER] Original widget URL: $widgetUrl');
      
      // Replace localhost URLs with the stored API base URL (which is the ngrok URL)
      // The backend returns localhost in widget URLs, but we need to use the public URL
      final apiBaseUrl = _prefs.getString('api_base_url');
      if (apiBaseUrl != null && widgetUrl.contains('localhost')) {
        debugPrint('[WIDGET_LOADER] Replacing localhost in widget URL');
        // Replace localhost:port with the API base URL
        final uri = Uri.parse(widgetUrl);
        final newUri = Uri.parse(apiBaseUrl).replace(
          path: uri.path,
        );
        widgetUrl = newUri.toString();
        debugPrint('[WIDGET_LOADER] Updated widget URL: $widgetUrl');
      }
      
      debugPrint('[WIDGET_LOADER] Loading widget data from: $widgetUrl');
      final widgetData = await loadWidget(widgetUrl);
      debugPrint('[WIDGET_LOADER] Widget data loaded, rendering...');
      
      return renderWidget(widgetData, ref: ref);
    } catch (e, stackTrace) {
      debugPrint('[WIDGET_LOADER] ERROR in loadAndRenderWidget: $e');
      debugPrint('[WIDGET_LOADER] Stack trace: $stackTrace');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error loading widget: $e',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }
}
