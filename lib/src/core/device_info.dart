import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:android_id/android_id.dart';
import 'package:flutter/foundation.dart';

class DeviceInfoProvider {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  Future<Map<String, dynamic>> getDeviceMetadata() async {
    final metadata = <String, dynamic>{'platform': _getPlatformName()};

    try {
      if (kIsWeb) {
        final info = await _deviceInfo.webBrowserInfo;
        metadata['browserName'] = info.browserName.name;
        metadata['platformVersion'] = info.appVersion;
        metadata['userAgent'] = info.userAgent;
      } else if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        metadata['model'] = info.model;
        metadata['brand'] = info.brand;
        metadata['version'] = info.version.release;
        metadata['sdkInt'] = info.version.sdkInt;
        metadata['id'] = info.id; // Unique ID for Android
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        metadata['model'] = info.model;
        metadata['name'] = info.name;
        metadata['systemName'] = info.systemName;
        metadata['systemVersion'] = info.systemVersion;
        metadata['identifierForVendor'] = info.identifierForVendor;
      } else if (Platform.isMacOS) {
        final info = await _deviceInfo.macOsInfo;
        metadata['model'] = info.model;
        metadata['osName'] = info.osRelease;
        metadata['computerName'] = info.computerName;
      }
    } catch (e) {
      metadata['error'] = 'Failed to get device info: $e';
    }

    return metadata;
  }

  // Best effort device ID independent of session
  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid) {
        const androidIdPlugin = AndroidId();
        final String? androidId = await androidIdPlugin.getId();
        return androidId ?? 'unknown_android';
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.identifierForVendor ?? 'unknown_ios';
      }
      // Fallback for others or if method fails
      return 'unknown_device';
    } catch (e) {
      return 'unknown_error';
    }
  }

  String _getPlatformName() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isFuchsia) return 'fuchsia';
    return 'unknown';
  }
}
