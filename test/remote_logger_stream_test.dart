import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_remote_logger/flutter_remote_logger.dart';
import 'package:flutter_remote_logger/src/core/device_info.dart';
import 'package:flutter_remote_logger/src/core/session_manager.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'remote_logger_test.mocks.dart';

// Reuse mocks from remote_logger_test
@GenerateMocks([LogStorage, LogUploader, SessionManager, DeviceInfoProvider])
void main() {
  late RemoteLogger logger;
  late MockLogStorage mockStorage;
  late MockLogUploader mockUploader;
  late MockSessionManager mockSessionManager;
  late MockDeviceInfoProvider mockDeviceInfoProvider;

  setUp(() {
    logger = RemoteLogger();
    logger.reset();
    mockStorage = MockLogStorage();
    mockUploader = MockLogUploader();
    mockSessionManager = MockSessionManager();
    mockDeviceInfoProvider = MockDeviceInfoProvider();

    when(mockSessionManager.sessionId).thenReturn('test_session');
    when(mockSessionManager.startTime).thenReturn(1234567890);
    when(
      mockDeviceInfoProvider.getDeviceMetadata(),
    ).thenAnswer((_) async => {});
    when(
      mockDeviceInfoProvider.getDeviceId(),
    ).thenAnswer((_) async => 'test_device');
    when(mockStorage.initialize(any)).thenAnswer((_) async {});
    // Use specific string to avoid implementation issues with 'any' being null
    when(
      mockStorage.getOldSessionFiles('test_session'),
    ).thenAnswer((_) async => []);
  });

  test('should emit RemoteLoggerSuccess when upload succeeds', () async {
    final file = File('test.log');
    await file.writeAsString('test');

    // Setup getSessionFile before it's called
    when(mockStorage.getSessionFile()).thenAnswer((_) async => file);

    await logger.initialize(
      storage: mockStorage,
      uploader: mockUploader,
      sessionManager: mockSessionManager,
      deviceInfoProvider: mockDeviceInfoProvider,
    );

    when(mockUploader.uploadSession(any, any)).thenAnswer((_) async {});

    // Listen
    expectLater(logger.events, emits(isA<RemoteLoggerSuccess>()));

    await logger.uploadCurrentSession();

    if (await file.exists()) await file.delete();
  });

  test('should emit RemoteLoggerError when upload fails', () async {
    final file = File('test_error.log');
    await file.writeAsString('test');

    // Setup getSessionFile before it's called
    when(mockStorage.getSessionFile()).thenAnswer((_) async => file);

    await logger.initialize(
      storage: mockStorage,
      uploader: mockUploader,
      sessionManager: mockSessionManager,
      deviceInfoProvider: mockDeviceInfoProvider,
    );

    when(
      mockUploader.uploadSession(any, any),
    ).thenThrow(Exception('Upload failed'));

    // Listen
    expectLater(logger.events, emits(isA<RemoteLoggerError>()));

    await logger.uploadCurrentSession();
    if (await file.exists()) await file.delete();
  });
}
