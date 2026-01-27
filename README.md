# Flutter Via File

A robust **Remote Logging and Profiling** package for Flutter applications.

`flutter_remote_logger` captures logs, device metadata, and session information, buffers them locally, and uploads them to a remote target (defaulting to Firebase) entirely in the background logic. It solves the problem of "profiling sessions" where you need to trace user behavior or debug issues on specific devices, even linking anonymous sessions to authenticated users later.

## Features

*   **Session-based Logging**: Every app launch creates a unique Session ID.
*   **Automatic Metadata**: Captures OS, Version, Device Model, and more automatically.
*   **Local Buffering**: Logs are written to secure local storage (`.jsonl` files) before uploading, preventing data loss on crashes.
*   **Firebase Integration**: Comes with a built-in `FirebaseLogUploader` that syncs logs to Firebase Storage and metadata to Cloud Firestore.
*   **User Linking**: Link an anonymous device session to a User ID at any point (e.g. after login).
*   **Customizable**: Implement your own `LogStorage` or `LogUploader` to use your own backend.

## Getting Started

### 1. Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_remote_logger:
    git:
      url: https://github.com/your_repo/flutter_remote_logger.git
      # OR, if published:
      # flutter_remote_logger: ^0.0.1
```

### 2. Firebase Configuration (Optional but recommended)

If you use the default `FirebaseLogUploader`, ensure you have configured Firebase in your Flutter app:

```bash
flutter pub add firebase_core firebase_storage cloud_firestore
```

And initialized it in your main:

```dart
await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
```

**Firestore Rules**: Ensure your Firestore and Storage have appropriate write rules.
*   **Storage path**: `logs/{deviceId}/{sessionId}.jsonl`
*   **Firestore path**: `sessions/{sessionId}`

## Usage

### Initialization

Initialize `RemoteLogger` as early as possible.

```dart
import 'package:flutter_remote_logger/flutter_remote_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize the logger
  await RemoteLogger().initialize();

  runApp(MyApp());
}
```

### Logging Events

Log anywhere in your app. The API is similar to standard logging.

```dart
// Simple info log
RemoteLogger().log('App loaded successfully');

// Log with level and custom tag
RemoteLogger().log('Database connected', level: 'DEBUG', tag: 'DB');

// Log structured data (Payload)
try {
  // ... risky code
} catch (e) {
  RemoteLogger().log(
    'Initialization failed', 
    level: 'ERROR', 
    payload: {
      'error': e.toString(),
      'retryCount': 3,
    }
  );
}
```

### Linking User

When a user authenticates, you can link their specific User ID to the current session (and device). This facilitates finding logs for a specific customer later.

```dart
void onUserLogin(String userId) {
  RemoteLogger().identifyUser(userId);
}
```

This will:
1.  Update the current session metadata in Firestore.
2.  Store a permanent link between this `deviceId` and `userId` in a `user_device_links` collection.

### Force Upload

Logs are files. By default, you might want to upload them at start-up (uploading previous sessions) or periodically.
You can trigger a manual upload of the *current* session file at any time:

```dart
await RemoteLogger().uploadCurrentSession();
```

## Architecture

The package is designed to be modular.

### Core Components

*   **RemoteLogger**: The singleton facade you interact with.
*   **SessionManager**: Handles UUID generation for sessions.
*   **DeviceInfoProvider**: Abstracts `device_info_plus` to provide unified metadata.

### Data Layer (Interfaces)

You can override these by passing them to `RemoteLogger().initialize()`.

*   **LogStorage**: Controls where logs are temporarily saved.
    *   *Default*: `FileLogStorage` (local app documents directory).
*   **LogUploader**: Controls where logs go.
    *   *Default*: `FirebaseLogUploader`.

## Contributing

Contributions are welcome! Please submit a PR or open an issue.

## License

MIT License. See LICENSE file.
