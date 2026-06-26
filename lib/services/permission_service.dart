import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:google_fonts/google_fonts.dart';

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
    
    if (context.mounted) {
      await checkAndRequestBatteryOptimization(context);
    }

    return {
      Permission.locationWhenInUse: locationStatus,
      Permission.locationAlways: backgroundStatus,
      Permission.systemAlertWindow: overlayStatus,
      Permission.notification: notificationStatus,
    };
  }

  /// Check and request battery optimization exemption on Android
  Future<void> checkAndRequestBatteryOptimization(BuildContext context) async {
    if (!Platform.isAndroid) return;

    final isOptimized = await Permission.ignoreBatteryOptimizations.isGranted;
    if (isOptimized) {
      _logger.i('🔋 Battery optimization exemption already granted.');
      return;
    }

    _logger.i('🔋 Battery optimization exemption NOT granted. Showing explanation dialog...');

    if (!context.mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.battery_alert_rounded, color: Color(0xFFF59E0B), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Optimize Battery Usage',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'To ensure continuous location tracking during your rides and prevent the system from killing the app in the background, please exempt MLT Driver from battery optimizations.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'In the next system dialog, please tap "Allow".',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E6BFF),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6B7280),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E6BFF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: Text(
              'Proceed',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (proceed == true && context.mounted) {
      _logger.i('🔋 Launching system battery optimization request...');
      final status = await Permission.ignoreBatteryOptimizations.request();
      _logger.i('🔋 Battery optimization request result: $status');
    }
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

  Future<bool> openSettings() async {
    return await openAppSettings();
  }
}
