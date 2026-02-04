# Flutter Remote Logger

A robust **Remote Logging and Profiling** package for Flutter applications.

`flutter_remote_logger` captures logs, device metadata, and session information, buffers them locally, and uploads them to a remote target (Firebase or Supabase) entirely in the background logic. It solves the problem of "profiling sessions" where you need to trace user behavior or debug issues on specific devices, even linking anonymous sessions to authenticated users later.

## Table of Contents

- [Features](#features)
- [Getting Started](#getting-started)
  - [Installation](#installation)
  - [Configuration](#configuration)
    - [Option A: Firebase](#option-a-firebase)
    - [Option B: Supabase](#option-b-supabase)
- [Usage](#usage)
  - [Initialization](#initialization)
  - [Logging Events](#logging-events)
  - [Linking User](#linking-user)
  - [Force Upload](#force-upload)
- [Architecture](#architecture)
- [Contributing](#contributing)
- [License](#license)

## Features

*   **Session-based Logging**: Every app launch creates a unique Session ID.
*   **Automatic Metadata**: Captures OS, Version, Device Model, and more automatically.
*   **Persistent Device ID**:
    *   **Android**: Uses `android_id` for persistence.
    *   **iOS**: Uses Keychain storage for persistence.
    *   **Desktop**: Uses file-based storage in Application Support (macOS, Windows, Linux).
*   **Nested Remote Paths**: Supports uploading logs to custom nested folder structures.
*   **Local Buffering**: Logs are written synchronously to secure local storage (`.jsonl` files).
*   **Backend Agnostic**: Comes with built-in uploaders for **Firebase** and **Supabase**, but you can implement your own.
*   **User Linking**: Link an anonymous device session to a User ID at any point.

## Getting Started

### Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_remote_logger:
    git:
      url: https://github.com/infodreams-software/flutter-remote-logger.git
      # OR, if published:
      # flutter_remote_logger: ^0.3.0
```

### Configuration

You need to choose a backend to store your logs.

#### Option A: Firebase

1.  **Dependencies**: Add `firebase_core`, `firebase_storage`, and `cloud_firestore` to your app.
2.  **Initialization**: Initialize Firebase in your `main.dart`.
3.  **Rules**: Ensure your Firestore and Storage have appropriate write rules.
    *   **Storage path**: `logs/{deviceId}/{sessionId}.jsonl` (default) or `{remotePath}/{deviceId}/{sessionId}.jsonl`
    *   **Firestore path**: `sessions/{sessionId}`

#### Option B: Supabase

To use Supabase, you need to set up your project with the required tables and storage bucket.

1.  **Dependencies**: Add `supabase_flutter` to your app.
2.  **Run Setup SQL**: Login to your Supabase Dashboard, go to the **SQL Editor**, and run the following script to create the necessary tables and buckets:

```sql
-- 1. Create Storage Bucket for logs
INSERT INTO storage.buckets (id, name, public) 
VALUES ('remote_logs', 'remote_logs', true)
ON CONFLICT (id) DO NOTHING;

-- Policy to allow uploading logs (Adjust capabilities as needed)
CREATE POLICY "Allow public uploads" ON storage.objects
FOR INSERT WITH CHECK ( bucket_id = 'remote_logs' );

CREATE POLICY "Allow public reads" ON storage.objects
FOR SELECT USING ( bucket_id = 'remote_logs' );

-- 2. Create Sessions Table
CREATE TABLE IF NOT EXISTS public.remote_log_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id TEXT NOT NULL UNIQUE,
    device_id TEXT NOT NULL,
    start_time TIMESTAMP WITH TIME ZONE,
    uploaded_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    user_id TEXT,
    log_file_url TEXT,
    custom_data JSONB DEFAULT '{}'::jsonb
);

-- 3. Create Device Links Table (for User Identity)
CREATE TABLE IF NOT EXISTS public.remote_log_device_links (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    device_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    linked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Enable RLS (Security)
ALTER TABLE public.remote_log_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.remote_log_device_links ENABLE ROW LEVEL SECURITY;

-- 5. Create Open Policies (⚠️ FAST SETUP ONLY - Restrict in Production!)
-- These policies allow anyone (even unauthenticated) to insert logs.
CREATE POLICY "Enable insert for all" ON public.remote_log_sessions
FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable select for all" ON public.remote_log_sessions
FOR SELECT USING (true);

CREATE POLICY "Enable insert for all" ON public.remote_log_device_links
FOR INSERT WITH CHECK (true);
```

3.  **Reload Schema Cache**: After running the SQL, execute this command to ensure the API knows about the new tables:
    ```sql
    NOTIFY pgrst, 'reload config';
    ```

## Usage

### Initialization

Initialize `RemoteLogger` early in your app lifecycle. You must inject the appropriate `LogUploader`.

**Example: Using Firebase**
```dart
import 'package:flutter_remote_logger/flutter_remote_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Initialize with FirebaseUploader (default is null/noop if not provided?)
  // Actually, you typically just let it rely on default imports or pass explicitly:
  await RemoteLogger().initialize(
    uploader: FirebaseLogUploader(),
    // Optional: Upload logs every 5 minutes automatically
    autoUploadFrequency: const Duration(minutes: 5),
    // Optional: Organize logs in a specific remote folder
    remotePath: 'my_project/v1.0', 
  );

  runApp(MyApp());
}
```

**Example: Using Supabase**
```dart
import 'package:flutter_remote_logger/flutter_remote_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  await RemoteLogger().initialize(
    uploader: SupabaseLogUploader(
      supabaseClient: Supabase.instance.client,
      // Optional: configuration
      // bucketName: 'my_logs',
    ),
    // Optional: Organize logs in a specific remote folder (e.g. project/version)
    remotePath: 'my_app/production',
    isEnabled: true,
  );

  // You can now access the stable Device ID used for sessions
  print('Device ID: ${RemoteLogger().deviceId}');

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

When a user authenticates, linking their User ID to the session allows you to find their logs later by User ID instead of just Device ID.

```dart
void onUserLogin(String userId) {
  RemoteLogger().identifyUser(userId);
}
```

### Force Upload

Logs are locally buffered in files. You can trigger a manual upload of the *current* session file at any time (e.g. on important errors or app pause).

```dart
await RemoteLogger().uploadCurrentSession();
```

await RemoteLogger().uploadCurrentSession();
```

### Handling Errors and Events

You can listen to the `events` stream to receive real-time feedback about upload operations, including errors (e.g., network issues, permission denied) and successes.

```dart
RemoteLogger().events.listen((event) {
  if (event is RemoteLoggerError) {
    print('RemoteLogger Error: ${event.message} - ${event.error}');
  } else if (event is RemoteLoggerSuccess) {
    print('RemoteLogger Success: ${event.message}');
  }
});
```

## Architecture

The package is designed to be modular.

*   **RemoteLogger**: The singleton facade.
*   **LogStorage**: Controls where logs are temporarily saved (Default: `FileLogStorage`).
*   **LogUploader**: Controls where logs go (implementations: `FirebaseLogUploader`, `SupabaseLogUploader`).

## Contributing

Contributions are welcome! Please submit a PR or open an issue.

## License

MIT License. See LICENSE file.
