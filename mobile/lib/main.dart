import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/permissions/permission_service.dart';
import 'features/enrollment/screens/qr_scanner_screen.dart';
import 'features/messaging/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Request all permissions on app start
  await PermissionService.requestAllPermissions();
  
  runApp(
    const ProviderScope(
      child: PosduifMobileApp(),
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
              path: '/home',
              builder: (context, state) => HomeScreen(),
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
      
      // Must have both device_id and api_base_url to be considered enrolled
      if (deviceId == null || apiBaseUrl == null) {
        debugPrint('[MAIN] Enrollment status: false (missing device_id or api_base_url)');
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
        await prefs.remove('app_instructions');
        await prefs.remove('app_instructions_url');
        debugPrint('[MAIN] Enrollment status: false (localhost detected and cleared)');
        return false;
      }
      
      // Verify app_instructions_url is saved (optional but helpful)
      final appInstructionsUrl = prefs.getString('app_instructions_url');
      if (appInstructionsUrl != null) {
        debugPrint('[MAIN] Found app_instructions_url: $appInstructionsUrl');
        // Validate it's not localhost
        if (appInstructionsUrl.contains('localhost') || appInstructionsUrl.contains('127.0.0.1')) {
          debugPrint('[MAIN] WARNING: app_instructions_url is localhost - clearing');
          await prefs.remove('app_instructions_url');
        }
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
