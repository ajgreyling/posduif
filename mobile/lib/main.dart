import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/permissions/permission_service.dart';
import 'features/enrollment/screens/qr_scanner_screen.dart';
import 'features/messaging/screens/home_screen.dart';
import 'features/auth/screens/username_selection_screen.dart';
import 'features/messaging/screens/chat_screen.dart';
import 'core/providers/providers.dart';
import 'core/enrollment/enrollment_service.dart';

Future<void> _initializeApp(ProviderContainer container) async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('user_id');
  if (userId != null) {
    container.read(currentUserIdProvider.notifier).state = userId;
  }
}

/// Detect Hot Restart and clear enrollment data in debug mode
/// Uses timestamp-based approach: if last_app_start_timestamp is missing or old (> 5 seconds),
/// it indicates a Hot Restart and enrollment data should be cleared
Future<void> _handleHotRestart() async {
  if (!kDebugMode) {
    return; // Only clear enrollment data in debug mode
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final lastStartTimestamp = prefs.getInt('last_app_start_timestamp');
    final now = DateTime.now().millisecondsSinceEpoch;
    const thresholdSeconds = 5; // If timestamp is older than 5 seconds, consider it a restart

    if (lastStartTimestamp == null) {
      // First run or data was cleared - update timestamp
      debugPrint('[MAIN] First run detected - setting timestamp');
      await prefs.setInt('last_app_start_timestamp', now);
      return;
    }

    final timeSinceLastStart = (now - lastStartTimestamp) / 1000; // Convert to seconds

    if (timeSinceLastStart > thresholdSeconds) {
      // Hot Restart detected - clear enrollment data
      debugPrint('[MAIN] Hot Restart detected (${timeSinceLastStart.toStringAsFixed(1)}s since last start) - clearing enrollment data');
      await EnrollmentService.clearEnrollmentData();
    } else {
      debugPrint('[MAIN] Normal app start (${timeSinceLastStart.toStringAsFixed(1)}s since last start) - keeping enrollment data');
    }

    // Update timestamp for next check
    await prefs.setInt('last_app_start_timestamp', now);
  } catch (e) {
    debugPrint('[MAIN] Error handling Hot Restart detection: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Handle Hot Restart detection and clear enrollment data if needed (debug mode only)
  await _handleHotRestart();
  
  // Request all permissions on app start
  await PermissionService.requestAllPermissions();
  
  final container = ProviderContainer();
  
  // Initialize current user ID if enrolled
  await _initializeApp(container);
  
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const PosduifMobileApp(),
    ),
  );
}

class PosduifMobileApp extends StatelessWidget {
  const PosduifMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkEnrollment(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final isEnrolled = snapshot.data ?? false;
        final initialLocation = isEnrolled ? '/home' : '/scanner';

        final router = GoRouter(
          initialLocation: initialLocation,
          redirect: (context, state) async {
            final location = state.uri.path;
            debugPrint('[ROUTER] Redirect check for location: $location');
            final enrolled = await _checkEnrollment();
            debugPrint('[ROUTER] Enrollment status: $enrolled');
            
            // If trying to access /home but not enrolled, redirect to scanner
            if (location == '/home' && !enrolled) {
              debugPrint('[ROUTER] Redirecting /home -> /scanner (not enrolled)');
              return '/scanner';
            }
            
            // If trying to access /scanner but already enrolled, redirect to home
            if (location == '/scanner' && enrolled) {
              debugPrint('[ROUTER] Redirecting /scanner -> /home (already enrolled)');
              return '/home';
            }
            
            debugPrint('[ROUTER] No redirect needed');
            return null; // No redirect needed
          },
          routes: [
            GoRoute(
              path: '/scanner',
              builder: (context, state) => QRScannerScreen(),
            ),
            GoRoute(
              path: '/username-selection',
              builder: (context, state) {
                final extra = state.extra as Map<String, dynamic>?;
                return UsernameSelectionScreen(
                  token: extra?['token'],
                  deviceId: extra?['deviceId'],
                  deviceInfo: extra?['deviceInfo'],
                );
              },
            ),
            GoRoute(
              path: '/home',
              builder: (context, state) => HomeScreen(),
            ),
            GoRoute(
              path: '/conversations',
              builder: (context, state) => HomeScreen(),
            ),
            GoRoute(
              path: '/chat/:recipientId',
              builder: (context, state) {
                final recipientId = state.pathParameters['recipientId']!;
                return ChatScreen(recipientId: recipientId);
              },
            ),
          ],
        );

        return MaterialApp.router(
          title: 'Posduif Mobile',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          routerConfig: router,
        );
      },
    );
  }

  Future<bool> _checkEnrollment() async {
    try {
      debugPrint('[MAIN] Checking enrollment status...');
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      final apiBaseUrl = prefs.getString('api_base_url');
      
      debugPrint('[MAIN] device_id: ${deviceId ?? "null"}');
      debugPrint('[MAIN] api_base_url: ${apiBaseUrl ?? "null"}');
      
      final userId = prefs.getString('user_id');
      
      // Must have device_id, api_base_url, and user_id to be considered enrolled
      if (deviceId == null || apiBaseUrl == null || userId == null) {
        debugPrint('[MAIN] Enrollment status: false (missing device_id, api_base_url, or user_id)');
        return false;
      }
      
      // Check if api_base_url is localhost - this won't work from mobile device
      // Treat localhost as invalid enrollment
      if (apiBaseUrl.contains('localhost') || apiBaseUrl.contains('127.0.0.1')) {
        debugPrint('[MAIN] WARNING: api_base_url is localhost - invalid for mobile device');
        debugPrint('[MAIN] Clearing invalid enrollment data...');
        // Clear the invalid enrollment data
        await prefs.remove('device_id');
        await prefs.remove('api_base_url');
        await prefs.remove('tenant_id');
        await prefs.remove('user_id');
        debugPrint('[MAIN] Enrollment status: false (localhost detected and cleared)');
        return false;
      }
      
      final isEnrolled = true;
      debugPrint('[MAIN] Enrollment status: $isEnrolled');
      
      return isEnrolled;
    } catch (e) {
      debugPrint('[MAIN] Error checking enrollment: $e');
      return false;
    }
  }
}
