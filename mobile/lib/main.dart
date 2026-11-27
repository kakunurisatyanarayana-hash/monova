import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/cloud.dart';
import 'core/cloud_sync.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cloud sync is optional: if Firebase is not configured or cannot start, the app runs offline as before.
  await startCloud();
  // Sync once at start, without waiting for a button press. It does nothing unless the owner is signed in.
  AutoSync.atStart();
  WidgetsBinding.instance.addObserver(_SyncOnResume());
  runApp(const ProviderScope(child: MonovaApp()));
}

/// Syncs again whenever the app comes back to the foreground. AutoSync limits how often this really runs.
class _SyncOnResume extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) AutoSync.run();
  }
}
