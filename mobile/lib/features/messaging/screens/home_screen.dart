import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/remote_widgets/widget_loader.dart';
import 'package:dio/dio.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Widget? _loadedWidget;
  bool _isLoading = true;
  bool _isCheckingEnrollment = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkEnrollmentAndLoadWidgets();
  }

  Future<void> _checkEnrollmentAndLoadWidgets() async {
    debugPrint('[HOME] Starting enrollment check and widget loading...');
    try {
      setState(() {
        _isLoading = true;
        _isCheckingEnrollment = true;
        _error = null;
      });

      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      final apiBaseUrl = prefs.getString('api_base_url');
      
      debugPrint('[HOME] device_id: ${deviceId ?? "null"}');
      debugPrint('[HOME] api_base_url: ${apiBaseUrl ?? "null"}');
      
      // First, verify enrollment status - must have both device_id and api_base_url
      if (deviceId == null || apiBaseUrl == null) {
        debugPrint('[HOME] Not enrolled - redirecting to scanner');
        // Not enrolled - redirect to scanner
        if (mounted) {
          context.go('/scanner');
        }
        return;
      }
      
      // Check if api_base_url is localhost - this won't work from mobile device
      if (apiBaseUrl.contains('localhost') || apiBaseUrl.contains('127.0.0.1')) {
        debugPrint('[HOME] WARNING: api_base_url is localhost - invalid for mobile device');
        debugPrint('[HOME] Clearing invalid enrollment and redirecting to scanner...');
        // Clear the invalid enrollment data
        await prefs.remove('device_id');
        await prefs.remove('api_base_url');
        await prefs.remove('tenant_id');
        await prefs.remove('user_id');
        await prefs.remove('app_instructions');
        // Redirect to scanner
        if (mounted) {
          context.go('/scanner');
        }
        return;
      }

      debugPrint('[HOME] Enrollment verified, loading widgets...');
      setState(() {
        _isCheckingEnrollment = false;
      });

      // Now load widgets only after confirming enrollment
      debugPrint('[HOME] Creating Dio client with baseUrl: $apiBaseUrl');
      final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
      final widgetLoader = RemoteWidgetLoader(dio, prefs, ref);

      // Load the inbox widget
      debugPrint('[HOME] Loading inbox widget...');
      final inboxWidget = await widgetLoader.loadAndRenderWidget('inbox', ref: ref);
      debugPrint('[HOME] Inbox widget loaded successfully');

      if (mounted) {
        setState(() {
          _loadedWidget = inboxWidget;
          _isLoading = false;
        });
        debugPrint('[HOME] Widget state updated');
      }
    } catch (e, stackTrace) {
      debugPrint('[HOME] Error in _checkEnrollmentAndLoadWidgets: $e');
      debugPrint('[HOME] Stack trace: $stackTrace');
      
      if (mounted) {
        // If error loading widgets, check if it's an enrollment issue
        final prefs = await SharedPreferences.getInstance();
        final deviceId = prefs.getString('device_id');
        final apiBaseUrl = prefs.getString('api_base_url');
        
        debugPrint('[HOME] Error handler - device_id: ${deviceId ?? "null"}');
        debugPrint('[HOME] Error handler - api_base_url: ${apiBaseUrl ?? "null"}');
        
        if (deviceId == null || apiBaseUrl == null) {
          debugPrint('[HOME] Not enrolled after error - redirecting to scanner');
          // Not enrolled - redirect to scanner
          context.go('/scanner');
          return;
        }
        
        debugPrint('[HOME] Setting error state: $e');
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If checking enrollment, show loading
    if (_isCheckingEnrollment || _isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Posduif Mobile'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Error loading widgets',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _checkEnrollmentAndLoadWidgets,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // If widget loaded successfully, render it
    return _loadedWidget ?? const Center(
      child: Text('No widgets loaded'),
    );
  }
}
