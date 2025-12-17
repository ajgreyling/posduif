import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestAllPermissions() async {
    final permissions = [
      Permission.camera,
      Permission.storage,
      Permission.notification,
      Permission.location,
      Permission.contacts,
      Permission.phone,
      Permission.sms,
    ];

    final statuses = await permissions.request();
    
    // Check if all permissions are granted
    for (final status in statuses.values) {
      if (!status.isGranted) {
        return false;
      }
    }
    
    return true;
  }

  static Future<Map<Permission, PermissionStatus>> checkAllPermissions() async {
    final permissions = [
      Permission.camera,
      Permission.storage,
      Permission.notification,
      Permission.location,
      Permission.contacts,
      Permission.phone,
      Permission.sms,
    ];

    return await permissions.request();
  }

  static Future<bool> isCameraGranted() async {
    return await Permission.camera.isGranted;
  }

  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }
}

