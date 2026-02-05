import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'package:flutter_remote_logger/src/core/device_info.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  @override
  Future<String?> getApplicationSupportPath() async {
    return '.';
  }
}

void main() {
  group('DeviceInfoProvider', () {
    tearDown(() {
      final file = File('./remote_logger_device_id');
      if (file.existsSync()) {
        file.deleteSync();
      }
    });

    test('getDeviceId returns something', () async {
      // Register mock path provider for desktop logic
      PathProviderPlatform.instance = MockPathProviderPlatform();

      final provider = DeviceInfoProvider();
      final id = await provider.getDeviceId();
      expect(id, isNotEmpty);
      expect(id, isNot('unknown_error'));
    });
  });
}
