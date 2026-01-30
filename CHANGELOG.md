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
