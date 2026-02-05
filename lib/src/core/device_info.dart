import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// A provider that supplies device metadata and unique device identifiers.
///
/// Supports Android, iOS, Web, macOS, Windows, and Linux.
///
/// On **Android**, it uses `Settings.Secure.ANDROID_ID` for persistence.
/// On **iOS**, it uses `flutter_secure_storage` (Keychain) to persist the ID across installs.
/// On **Desktop** (macOS, Windows, Linux), it stores a UUID in the application support directory.
class DeviceInfoProvider {
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Returns a map of device metadata (model, OS version, etc.).
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

  /// Returns a persistent device ID.
  ///
  /// *   **Android**: Returns `android_id`.
  /// *   **iOS**: Returns a UUID stored in Keychain (persists across reinstalls).
  /// *   **Desktop**: Returns a UUID stored in `Application Support`.
  /// *   **Web**: Returns `unknown_device` (no reliable persistence).
  Future<String> getDeviceId() async {
    try {
      if (Platform.isAndroid ||
          Platform.isMacOS ||
          Platform.isWindows ||
          Platform.isLinux) {
        // For Android and Desktop, we store a UUID in a file in Application Support (FilesDir on Android)
        // This ensures:
        // 1. Persistence across app restarts (but not uninstalls, which fits the user requirement)
        // 2. Consistency between Flutter and Native Android (both access context.filesDir)
        try {
          final directory = await getApplicationSupportDirectory();
          final file = File('${directory.path}/remote_logger_device_id');
          if (await file.exists()) {
            final storedId = await file.readAsString();
            if (storedId.isNotEmpty) {
              return storedId;
            }
          }

          // Generate new ID
          final newId = const Uuid().v4();
          await file.create(recursive: true);
          await file.writeAsString(newId);
          return newId;
        } catch (e) {
          // Fallback
          if (Platform.isMacOS) {
            final info = await _deviceInfo.macOsInfo;
            return info.systemGUID ?? 'unknown_macos_${const Uuid().v4()}';
          }
          return 'unknown_device_${const Uuid().v4()}';
        }
      } else if (Platform.isIOS) {
        // Use Secure Storage (Keychain) for persistence across installs on iOS
        try {
          const storage = FlutterSecureStorage();
          final storedId = await storage.read(key: 'remote_logger_device_id');
          if (storedId != null && storedId.isNotEmpty) {
            return storedId;
          }

          final info = await _deviceInfo.iosInfo;
          // Fallback to identifierForVendor which is preserved as long as the vendor has at least one app installed
          final newId = info.identifierForVendor ?? 'unknown_ios';

          await storage.write(key: 'remote_logger_device_id', value: newId);
          return newId;
        } catch (e) {
          // Fallback if Secure Storage fails
          final info = await _deviceInfo.iosInfo;
          return info.identifierForVendor ?? 'unknown_ios';
        }
      } else if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        // For Desktop, we store a UUID in a file in Application Support
        try {
          final directory = await getApplicationSupportDirectory();
          final file = File('${directory.path}/remote_logger_device_id');
          if (await file.exists()) {
            final storedId = await file.readAsString();
            if (storedId.isNotEmpty) {
              return storedId;
            }
          }

          // Generate new ID
          final newId = const Uuid().v4();
          await file.create(recursive: true);
          await file.writeAsString(newId);
          return newId;
        } catch (e) {
          // If filesystem fails, fallback to platform specific info if possible, or temporary UUID
          if (Platform.isMacOS) {
            final info = await _deviceInfo.macOsInfo;
            return info.systemGUID ?? 'unknown_macos_${const Uuid().v4()}';
          }
          return 'unknown_desktop_${const Uuid().v4()}';
        }
      }
      // Fallback for Web
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
