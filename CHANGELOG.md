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
