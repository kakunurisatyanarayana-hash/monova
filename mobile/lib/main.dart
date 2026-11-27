import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/cloud.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cloud sync is optional: if Firebase is not configured or cannot start, the app runs offline as before.
  await startCloud();
  runApp(const ProviderScope(child: MonovaApp()));
}
