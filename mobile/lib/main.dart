import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    final router = GoRouter(
      initialLocation: '/scanner',
      routes: [
        GoRoute(
          path: '/scanner',
          builder: (context, state) => const QRScannerScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
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
  }
}
