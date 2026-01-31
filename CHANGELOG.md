## 0.3.0
* **Device ID Persistence**: Restored `android_id` usage for Android to ensure Device ID persists across app re-installs. This may cause the package to be labeled as "Android Only" on pub.dev, but it is necessary for consistent identification.
* **Nested Remote Paths**: Added `remotePath` parameter to `RemoteLogger.initialize()`. This allows checking logs into custom folder structures (e.g. `project_b/v1.0/`) in the remote storage bucket.
* **Breaking Change**: `LogUploader` interface methods `uploadSession` and `uploadDeviceInfo` now accept an optional `path` parameter.

## 0.2.8
* **Cross-Platform Support**: Removed dependency on `android_id` to ensure the package is recognized as supporting non-Android platforms (iOS, Web, etc.). Android Device ID now falls back to `Build.ID` via `device_info_plus`. (Reverted in 0.3.0 due to lack of persistence).

## 0.2.7
* **API Compatibility**: Restored `Future<void>` return type to `log()` method to fix build errors with existing `await` calls. The implementation remains synchronous (blocking I/O) for safety, but wrapped in a Future.

## 0.2.6
* **Synchronous Logging**: The `log()` method is now synchronous (`void` return type) and uses blocking file I/O. This ensures logs are written before the application exits or proceeds, eliminating race conditions. Compatibility with existing `await log()` calls is preserved (awaiting void).

## 0.2.5
* **Improved Sync**: Refined synchronization logic to use Process ID (PID) matching instead of file modification time. This prevents race conditions and ensures more robust coupling between Flutter and Native environments running in the same process.

## 0.2.4
* **Cross-Platform Synchronization**: Added `SessionSynchronizer` to ensure Flutter and Android logs share the same `groupSessionId` by reading/writing a shared lock file (`session.lock`) in the app's document directory.

## 0.2.3
* **Supabase Upload**: Filenames now include `groupSessionId` if present (e.g. `log_UUID_GROUPID.flutter.jsonl`) to enable easier coupling with other platform logs.
* **Session Info**: Added `groupSessionId` to `SessionInfo` model.

## 0.2.2
* **Device ID**: Changed Android Device ID generation to use `android_id` (Settings.Secure.ANDROID_ID) instead of `Build.ID` to match native Android behavior and ensure consistency.

## 0.2.1
* Improved documentation for pub.dev compliance.
* Fixed lints regarding braces in control flow structures.
* Validated `.flutter.jsonl` suffix for log files.

## 0.2.0
* **Session Synchronization**: Added automatic session ID synchronization with native Android logs using a file-based lock mechanism.
* **Platform Suffix**: Log files are now saved with a `.flutter.jsonl` suffix to distinguish them from native logs.
* **Device ID**: Exposed `deviceId` getter for easy retrieval of the unique device identifier.
* **Disable Logging**: Added `isEnabled` parameter to `initialize()` to globally disable logging and uploading.
* **Internal**: Implemented `SessionSynchronizer` logic.

## 0.1.3
* Added `time` field to `LogEntry` for human-readable ISO-8601 timestamps.
* Automatic upload of `device_info.json` to the device's log folder for easier identification.
* Updated `RemoteLogger` to handle device info upload on initialization.

## 0.1.2
* Added `events` stream to `RemoteLogger` for listening to upload success and errors.
* Added `RemoteLoggerEvent`, `RemoteLoggerSuccess`, and `RemoteLoggerError` classes.

## 0.1.1
* Added automatic log uploading (periodic and on startup).
* Improved `RemoteLogger` initialization to recover orphan sessions.

## 0.1.0
* Added `SupabaseLogUploader` for Supabase integration.
* Added documentation for Supabase setup.

## 0.0.1-beta1

* Initial release.
* Added `RemoteLogger` for session-based logging.
* Added `FileLogStorage` for local buffering.
* Added `FirebaseLogUploader` for backend integration.
* Added device metadata capture.
