import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../core/enrollment/enrollment_service.dart';
import '../../../core/device/device_service.dart';
import '../../../core/providers/providers.dart';

class UsernameSelectionScreen extends ConsumerStatefulWidget {
  final String? token;
  final String? deviceId;
  final Map<String, dynamic>? deviceInfo;

  const UsernameSelectionScreen({
    super.key,
    this.token,
    this.deviceId,
    this.deviceInfo,
  });

  @override
  ConsumerState<UsernameSelectionScreen> createState() => _UsernameSelectionScreenState();
}

class _UsernameSelectionScreenState extends ConsumerState<UsernameSelectionScreen> {
  String? _selectedUsername;
  bool _isCompleting = false;
  String? _error;

  final List<String> _mobileUsernames = [
    'Joe the Mobile User',
    'Sally the Mobile User',
  ];

  Future<void> _selectUsername(String username) async {
    if (widget.token == null || widget.deviceId == null) {
      setState(() {
        _error = 'Missing enrollment information';
      });
      return;
    }

    setState(() {
      _selectedUsername = username;
      _isCompleting = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final apiBaseUrl = prefs.getString('api_base_url');
      if (apiBaseUrl == null) {
        throw Exception('API base URL not found');
      }

      final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
      final enrollmentService = EnrollmentService(dio, prefs);

      // Get device info if not provided
      final deviceInfo = widget.deviceInfo ?? await DeviceService.getDeviceInfo();

      // Complete enrollment with username
      await enrollmentService.completeEnrollment(
        token: widget.token!,
        deviceId: widget.deviceId!,
        username: username,
        deviceInfo: deviceInfo,
      );

      // Initialize current user ID in provider
      final userId = prefs.getString('user_id');
      if (userId != null) {
        ref.read(currentUserIdProvider.notifier).state = userId;
      }

      // Navigate to conversation list
      if (mounted) {
        context.go('/conversations');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isCompleting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Username'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_outline,
                size: 80,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              const Text(
                'Choose your username',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
              if (_isCompleting)
                const CircularProgressIndicator()
              else
                ..._mobileUsernames.map((username) => Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _selectUsername(username),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            username,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}
