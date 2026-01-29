import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:logger/logger.dart';

class OverlayService {
  final Logger _logger = Logger();

  // Singleton
  static final OverlayService _instance = OverlayService._internal();
  factory OverlayService() => _instance;
  OverlayService._internal();

  /// Check if overlay permission is granted
  Future<bool> checkPermission() async {
    final status = await FlutterOverlayWindow.isPermissionGranted();
    _logger.d('Overlay permission status: $status');
    return status;
  }

  /// Request overlay permission
  Future<bool?> requestPermission() async {
    final status = await FlutterOverlayWindow.requestPermission();
    _logger.d('Overlay permission requested, result: $status');
    return status;
  }

  /// Show the floating overlay
  Future<void> showOverlay() async {
    if (await checkPermission()) {
      _logger.i('Showing overlay...');
      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: "Driver App",
        overlayContent: "Tap to return to app",
        flag: OverlayFlag.defaultFlag,
        alignment: OverlayAlignment.centerRight,
        visibility: NotificationVisibility.visibilitySecret,
        positionGravity: PositionGravity.right,
        height: 150, // Small bubble height
        width: 150,  // Small bubble width
      );
    } else {
      _logger.w('Cannot show overlay: Permission not granted');
    }
  }

  /// Hide the floating overlay
  Future<void> hideOverlay() async {
    _logger.i('Hiding overlay...');
    await FlutterOverlayWindow.closeOverlay();
  }
}
