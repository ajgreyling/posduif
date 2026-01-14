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
  final TextEditingController _urlController = TextEditingController();
  bool _isProcessing = false;
  String? _error;
  bool _isManualMode = false;

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

      debugPrint('[QR_SCANNER] Enrollment token validated, navigating to username selection...');
      // Navigate to username selection - enrollment will be completed there
      if (mounted) {
        context.go('/username-selection', extra: {'token': token, 'deviceId': deviceId, 'deviceInfo': deviceInfo});
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

  Future<void> _handleManualSubmit() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _error = 'Please enter an enrollment URL';
      });
      return;
    }
    await _handleQRCode(url);
  }

  @override
  void dispose() {
    _controller.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enroll Device'),
        actions: [
          IconButton(
            icon: Icon(_isManualMode ? Icons.qr_code_scanner : Icons.edit),
            onPressed: () {
              setState(() {
                _isManualMode = !_isManualMode;
                _error = null;
              });
            },
            tooltip: _isManualMode ? 'Switch to QR Scanner' : 'Switch to Manual Entry',
          ),
        ],
      ),
      body: _isManualMode ? _buildManualEntryView() : _buildScannerView(),
    );
  }

  Widget _buildScannerView() {
    return Stack(
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
    );
  }

  Widget _buildManualEntryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Icon(
            Icons.link,
            size: 64,
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter Enrollment URL',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Paste the enrollment URL from your browser or email',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _urlController,
            decoration: InputDecoration(
              labelText: 'Enrollment URL',
              hintText: 'https://example.com/api/enrollment/your-token-here',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            enabled: !_isProcessing,
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),
          if (_error != null) const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isProcessing ? null : _handleManualSubmit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Submit',
                    style: TextStyle(fontSize: 16),
                  ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isManualMode = false;
                _error = null;
              });
            },
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Switch to QR Scanner'),
          ),
        ],
      ),
    );
  }
}
