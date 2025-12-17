import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../../core/enrollment/enrollment_service.dart';
import '../../../core/device/device_service.dart';
import '../../../core/api/api_client.dart';

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
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      // Extract enrollment URL from QR code
      final uri = Uri.parse(code);
      final token = uri.pathSegments.last;

      // Get enrollment details
      final prefs = await SharedPreferences.getInstance();
      final apiBaseUrl = uri.origin;
      
      final dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
      final enrollmentService = EnrollmentService(dio, prefs);

      final enrollmentDetails = await enrollmentService.getEnrollmentDetails(token);
      
      if (!enrollmentDetails['valid']) {
        throw Exception('Enrollment token is invalid or expired');
      }

      // Get device ID
      final deviceId = await DeviceService.getDeviceId();
      final deviceInfo = await DeviceService.getDeviceInfo();

      // Complete enrollment
      await enrollmentService.completeEnrollment(
        token: token,
        deviceId: deviceId,
        deviceInfo: deviceInfo,
      );

      // Get app instructions
      await enrollmentService.getAppInstructions(deviceId);

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
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
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

