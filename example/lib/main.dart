import 'package:flutter/material.dart';
import 'package:flutter_remote_logger/flutter_remote_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (Assuming you have generated options)
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // For this example to compile without generated options, we comment it out or use a dummy.
  // In a real app, this is crucial.
  // await Firebase.initializeApp();

  // Initialize the logger
  // Passing null uses default FileLogStorage and FirebaseLogUploader
  // Note: FirebaseLogUploader needs Firebase to be initialized.
  await RemoteLogger().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Remote Logger Example')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  RemoteLogger().log('Button clicked', level: 'UserAction');
                },
                child: const Text('Log Action'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  RemoteLogger().identifyUser('example_user_id');
                },
                child: const Text('Identify User'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  await RemoteLogger().uploadCurrentSession();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Upload triggered')),
                    );
                  }
                },
                child: const Text('Force Upload'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
