import 'package:share_plus/share_plus.dart';

/// Shares plain text through the phone's share menu (WhatsApp, SMS, email, and so on). Free, and needs no server.
Future<void> shareText(String text, {String subject = ''}) async {
  await Share.share(text, subject: subject);
}
