import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../core/enrollment/enrollment_service.dart';
import '../../../core/device/device_service.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  String? _error;

  Future<void> _handleQRCode(String code) async {
    if (_isProcessing) {
      debugPrint('[QR_SCANNER] Already processing, ignoring QR code');
      return;
    }

    debugPrint('[QR_SCANNER] QR code scanned: $code');
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Extract enrollment URL from QR code
      debugPrint('[QR_SCANNER] Parsing QR code URL...');
      final uri = Uri.parse(code);
      final token = uri.pathSegments.last;
      debugPrint('[QR_SCANNER] Extracted token: $token');
      debugPrint('[QR_SCANNER] URI origin: ${uri.origin}');

      // Get enrollment details
      final prefs = await SharedPreferences.getInstance();
      final apiBaseUrl = uri.origin;
      
      debugPrint('[QR_SCANNER] Storing API base URL: $apiBaseUrl');
      // Store API base URL early so it's available for subsequent calls
      await prefs.setString('api_base_url', apiBaseUrl);
      
      debugPrint('[QR_SCANNER] Creating Dio client with baseUrl: $apiBaseUrl');
      final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
      final enrollmentService = EnrollmentService(dio, prefs);

      debugPrint('[QR_SCANNER] Getting enrollment details...');
      final enrollmentDetails = await enrollmentService.getEnrollmentDetails(token);
      debugPrint('[QR_SCANNER] Enrollment details: $enrollmentDetails');
      
      if (!enrollmentDetails['valid']) {
        debugPrint('[QR_SCANNER] ERROR: Enrollment token is invalid or expired');
        throw Exception('Enrollment token is invalid or expired');
      }

      debugPrint('[QR_SCANNER] Token is valid, getting device info...');
      // Get device ID
      final deviceId = await DeviceService.getDeviceId();
      final deviceInfo = await DeviceService.getDeviceInfo();
      debugPrint('[QR_SCANNER] Device ID: $deviceId');
      debugPrint('[QR_SCANNER] Device info: $deviceInfo');

      debugPrint('[QR_SCANNER] Completing enrollment...');
      // Complete enrollment
      await enrollmentService.completeEnrollment(
        token: token,
        deviceId: deviceId,
        deviceInfo: deviceInfo,
      );
      debugPrint('[QR_SCANNER] Enrollment completed successfully');

      debugPrint('[QR_SCANNER] Getting app instructions...');
      // Get app instructions (this will update the API base URL if different)
      try {
        final appInstructions = await enrollmentService.getAppInstructions(deviceId);
        debugPrint('[QR_SCANNER] App instructions retrieved successfully');
        debugPrint('[QR_SCANNER] App instructions version: ${appInstructions['version']}');
        debugPrint('[QR_SCANNER] App instructions tenant_id: ${appInstructions['tenant_id']}');
        debugPrint('[QR_SCANNER] App instructions widgets: ${appInstructions['widgets']?.keys}');
        
        // Verify app instructions URL is saved
        final savedInstructionsUrl = prefs.getString('app_instructions_url');
        debugPrint('[QR_SCANNER] Saved app_instructions_url: $savedInstructionsUrl');
        
        // Verify api_base_url is saved and not localhost
        final savedApiBaseUrl = prefs.getString('api_base_url');
        if (savedApiBaseUrl == null || savedApiBaseUrl.contains('localhost') || savedApiBaseUrl.contains('127.0.0.1')) {
          debugPrint('[QR_SCANNER] ERROR: api_base_url is invalid after enrollment');
          throw Exception('Invalid API base URL after enrollment. Please try again.');
        }
        debugPrint('[QR_SCANNER] Verified api_base_url: $savedApiBaseUrl');
      } catch (e) {
        debugPrint('[QR_SCANNER] ERROR getting app instructions: $e');
        // Clear partial enrollment data
        await prefs.remove('device_id');
        await prefs.remove('api_base_url');
        await prefs.remove('tenant_id');
        await prefs.remove('user_id');
        await prefs.remove('app_instructions');
        throw Exception('Failed to get app instructions: $e');
      }

      debugPrint('[QR_SCANNER] Navigating to home screen...');
      if (mounted) {
        context.go('/home');
      }
      debugPrint('[QR_SCANNER] Navigation complete');
    } catch (e, stackTrace) {
      debugPrint('[QR_SCANNER] ERROR in _handleQRCode: $e');
      debugPrint('[QR_SCANNER] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isProcessing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleQRCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (_error != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.red,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _isProcessing = false;
                        });
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          // Instructions overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Point your camera at the enrollment QR code',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
