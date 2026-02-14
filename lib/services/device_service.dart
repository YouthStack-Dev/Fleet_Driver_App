import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:android_id/android_id.dart';
import 'package:logger/logger.dart';

class DeviceService {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final _androidIdPlugin = const AndroidId();
  final Logger _logger = Logger();

  Future<Map<String, dynamic>> getDeviceData() async {
    String? androidId;
    String deviceModel = 'Unknown';
    String osVersion = 'Unknown';
    String appVersion = 'Unknown';

    try {
      // 1. Get App Version
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;

      // 2. Get Device Info & Android ID
      if (Platform.isAndroid) {
        androidId = await _androidIdPlugin.getId();
        final androidInfo = await _deviceInfo.androidInfo;
        deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
        osVersion = 'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
      } else if (Platform.isIOS) {
        // Fallback for iOS (though requirements specify Android ID)
        final iosInfo = await _deviceInfo.iosInfo;
        androidId = iosInfo.identifierForVendor; 
        deviceModel = '${iosInfo.name} ${iosInfo.model}';
        osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      }
    } catch (e) {
      _logger.e('Error getting device info: $e');
    }

    return {
      'android_id': androidId ?? 'unknown_id', 
      'device_model': deviceModel,
      'os_version': osVersion,
      'app_version': appVersion,
    };
  }
}
