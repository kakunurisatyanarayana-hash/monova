import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'bill_scanner.dart';
import 'card_text_parser.dart';
import 'photo_types.dart';

class CardScanResult {
  const CardScanResult(this.photo, this.parsed);

  final PickedPhoto photo;
  final ParsedCard parsed;
}

/// Takes a photo of a card (camera or gallery), reads the text on the phone, and returns the photo with the
/// number, expiry, name and bank that could be found. Nothing is sent to a server.
Future<CardScanResult> scanCardPhoto({required bool camera}) async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 90,
    );
  } catch (e) {
    throw BillScanException('The camera or photo library could not be opened. Details: $e');
  }
  if (file == null) throw const BillScanException('No photo was chosen.');

  final bytes = await file.readAsBytes();
  final mime = file.mimeType ?? (file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
    final parsed = parseCardText(result.text);
    return CardScanResult(PickedPhoto(bytes, mime), parsed);
  } catch (e) {
    throw BillScanException('The card photo could not be read. Details: $e');
  } finally {
    await recognizer.close();
  }
}
