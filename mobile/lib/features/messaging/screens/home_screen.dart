import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'conversation_list_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: _checkEnrollment(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final isEnrolled = snapshot.data ?? false;
        if (!isEnrolled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/scanner');
          });
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return const ConversationListScreen();
      },
    );
  }

  Future<bool> _checkEnrollment() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id');
    final apiBaseUrl = prefs.getString('api_base_url');
    final userId = prefs.getString('user_id');
    
    return deviceId != null && apiBaseUrl != null && userId != null &&
        !apiBaseUrl.contains('localhost') && !apiBaseUrl.contains('127.0.0.1');
  }
}
