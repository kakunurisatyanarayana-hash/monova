import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/qr_payloads.dart';

/// A QR code on a white card, with a title. The card can be captured as a picture with [captureQrPng].
class QrCard extends StatelessWidget {
  const QrCard({super.key, required this.payload, required this.boundaryKey, this.title = '', this.subtitle = '', this.size = 230});

  final String payload;
  final GlobalKey boundaryKey;
  final String title;
  final String subtitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title.isNotEmpty)
              Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w800)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            ],
            const SizedBox(height: 14),
            QrImageView(data: payload, size: size, errorCorrectionLevel: QrErrorCorrectLevel.M, backgroundColor: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// Captures the card under [key] as a PNG. Returns null if it is not on screen yet.
Future<Uint8List?> captureQrPng(GlobalKey key) async {
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) return null;
  final image = await boundary.toImage(pixelRatio: 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

/// Shares a PNG picture through the phone's share sheet (WhatsApp and other apps).
Future<void> shareQrPng(Uint8List png, {required String fileName, String text = ''}) async {
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(png, mimeType: 'image/png', name: fileName)],
    text: text.isEmpty ? null : text,
  ));
}

/// Words shown when a payload is too large for one code, and it is not made.
String? payloadProblem(String payload) => qrTooLong(payload);
