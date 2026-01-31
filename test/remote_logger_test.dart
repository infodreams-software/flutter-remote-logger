import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_remote_logger/flutter_remote_logger.dart';
import 'package:flutter_remote_logger/src/core/session_manager.dart';
import 'package:flutter_remote_logger/src/core/device_info.dart';

// Generate mocks
@GenerateMocks([LogStorage, LogUploader, SessionManager, DeviceInfoProvider])
import 'remote_logger_test.mocks.dart';

void main() {
  late RemoteLogger logger;
  late MockLogStorage mockStorage;
  late MockLogUploader mockUploader;
  late MockSessionManager mockSessionManager;
  late MockDeviceInfoProvider mockDeviceInfoProvider;

  setUp(() {
    logger = RemoteLogger();
    logger.reset(); // Reset state to ensure fresh mocks are used

    mockStorage = MockLogStorage();
    mockUploader = MockLogUploader();
    mockSessionManager = MockSessionManager();
    mockDeviceInfoProvider = MockDeviceInfoProvider();

    when(mockSessionManager.sessionId).thenReturn('test-session-id');
    when(mockSessionManager.startTime).thenReturn(1234567890);
    when(
      mockDeviceInfoProvider.getDeviceMetadata(),
    ).thenAnswer((_) async => {'platform': 'test'});
    when(
      mockDeviceInfoProvider.getDeviceId(),
    ).thenAnswer((_) async => 'test-device-id');
    when(mockStorage.initialize(any)).thenAnswer((_) async {});
    when(mockStorage.write(any)).thenAnswer((_) async {});
  });

  test('RemoteLogger initialization and logging', () async {
    await logger.initialize(
      storage: mockStorage,
      uploader: mockUploader,
      sessionManager: mockSessionManager,
      deviceInfoProvider: mockDeviceInfoProvider,
    );

    verify(mockStorage.initialize('test-session-id')).called(1);

    // Verify device info upload
    verify(
      mockUploader.uploadDeviceInfo('test-device-id', {'platform': 'test'}),
    ).called(1);

    await logger.log('Test message');
    final captured = verify(mockStorage.writeSync(captureAny)).captured;
    final entry = captured.first as LogEntry;

    expect(entry.message, equals('Test message'));
    expect(entry.level, equals('INFO'));
    expect(entry.time, isNotEmpty);
  });

  test('RemoteLogger identify user', () async {
    await logger.initialize(
      storage: mockStorage,
      uploader: mockUploader,
      sessionManager: mockSessionManager,
      deviceInfoProvider: mockDeviceInfoProvider,
    );

    await logger.identifyUser('user-123');

    verify(mockUploader.identifyUser('test-device-id', 'user-123')).called(1);
  });
}
