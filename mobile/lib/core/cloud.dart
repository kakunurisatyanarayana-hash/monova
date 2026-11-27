import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase settings are passed at build time, so nothing is written into the source code:
///   --dart-define=FIREBASE_PROJECT_ID=...  --dart-define=FIREBASE_SENDER_ID=...
///   --dart-define=FIREBASE_API_KEY=...     --dart-define=FIREBASE_WEB_APP_ID=...  (web)
///   --dart-define=FIREBASE_ANDROID_APP_ID=... (Android)
/// Without them the app stays fully offline and shows that cloud sync is not set up.
class CloudConfig {
  CloudConfig._();

  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const webAppId = String.fromEnvironment('FIREBASE_WEB_APP_ID');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');

  static String get appId => kIsWeb ? webAppId : androidAppId;

  static bool get isSet => projectId.isNotEmpty && senderId.isNotEmpty && apiKey.isNotEmpty && appId.isNotEmpty;
}

/// True once Firebase has started. Every cloud feature checks this and keeps working offline when it is false.
bool cloudReady = false;

/// Starts Firebase when it is configured. Never throws: a failure leaves the app offline, with the reason in the log.
Future<void> startCloud() async {
  if (!CloudConfig.isSet) return;
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: CloudConfig.apiKey,
        appId: CloudConfig.appId,
        messagingSenderId: CloudConfig.senderId,
        projectId: CloudConfig.projectId,
        authDomain: CloudConfig.authDomain.isEmpty ? null : CloudConfig.authDomain,
      ),
    );
    cloudReady = true;
  } catch (e) {
    debugPrint('Cloud sync did not start, staying offline: $e');
  }
}
