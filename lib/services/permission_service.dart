import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class PermissionService {
  final Logger _logger = Logger();

  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  /// Check and request all required permissions
  /// Returns map of permission statuses
  Future<Map<Permission, PermissionStatus>> checkAndRequestAllPermissions(BuildContext context) async {
    _logger.i('🔍 Checking all permissions...');
    
    // 1. Location (Foreground)
    PermissionStatus locationStatus = await Permission.locationWhenInUse.status;
    if (!locationStatus.isGranted) {
      _logger.i('📱 Requesting foreground location permission...');
      locationStatus = await Permission.locationWhenInUse.request();
    }

    // 2. Location (Background - 'Always')
    PermissionStatus backgroundStatus = await Permission.locationAlways.status;
    if (locationStatus.isGranted && !backgroundStatus.isGranted) {
       _logger.i('🌍 Requesting background location permission...');
       backgroundStatus = await Permission.locationAlways.request();
    }
    
    // PermissionStatus backgroundStatus = await Permission.locationAlways.status; // Just check status

    // 3. System Alert Window (Overlay)
    // Note: This ALWAYS redirects to settings. Skipping for "normal popup" flow.
    PermissionStatus overlayStatus = await Permission.systemAlertWindow.status;
    
    if (!overlayStatus.isGranted) {
      _logger.i('Requested System Alert Window permission');
       overlayStatus = await Permission.systemAlertWindow.request();
    }

    // Notification Permission (Android 13+)
    PermissionStatus notificationStatus = await Permission.notification.status;
    if (notificationStatus.isDenied) {
      notificationStatus = await Permission.notification.request();
    }

    _logger.i('Permission Statuses: Loc: $locationStatus, BG: $backgroundStatus, Overlay: $overlayStatus');
    
    return {
      Permission.locationWhenInUse: locationStatus,
      Permission.locationAlways: backgroundStatus,
      Permission.systemAlertWindow: overlayStatus,
      Permission.notification: notificationStatus,
    };
  }

  /// Show explanation dialog if permissions are permanently denied or needed
  Future<void> showPermissionDialog(BuildContext context, String title, String content) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<bool> hasLocationPermission() async {
    return await Permission.locationWhenInUse.isGranted || await Permission.locationAlways.isGranted;
  }
}
