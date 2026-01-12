import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/providers.dart';
import '../../../core/api/api_client.dart';

class EnrollmentScreen extends ConsumerStatefulWidget {
  const EnrollmentScreen({super.key});

  @override
  ConsumerState<EnrollmentScreen> createState() => _EnrollmentScreenState();
}

class _EnrollmentScreenState extends ConsumerState<EnrollmentScreen> {
  Map<String, dynamic>? _enrollmentData;
  bool _isLoading = false;
  String? _error;

  Future<void> _createEnrollment() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      final data = await apiClient.createEnrollment();
      setState(() {
        _enrollmentData = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enroll Mobile User'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_enrollmentData == null) ...[
                const Text(
                  'Generate a QR code for mobile user enrollment',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _createEnrollment,
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Generate QR Code'),
                ),
              ] else ...[
                const Text(
                  'Scan this QR code with the mobile app',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: QrImageView(
                      data: _enrollmentData!['qr_code_data']['enrollment_url'] as String,
                      version: QrVersions.auto,
                      size: 300.0,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Token: ${_enrollmentData!['token']}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _createEnrollment,
                  child: const Text('Generate New QR Code'),
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}



