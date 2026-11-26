import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'bill_text_parser.dart';

class BillScanException implements Exception {
  const BillScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Takes a photo of a bill (camera or gallery), reads its text on the phone, and finds the date, final amount and biller.
/// Nothing is sent to a server. The values are shown to the user to check before they are saved.
Future<ParsedBill> scanBillPhoto({required bool camera}) async {
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

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  try {
    final result = await recognizer.processImage(InputImage.fromFilePath(file.path));
    final parsed = parseBillText(result.text);
    if (parsed.isEmpty) {
      throw const BillScanException('The photo was read, but no date, amount or name was found. Try a flatter, brighter photo, or type the details.');
    }
    return parsed;
  } on BillScanException {
    rethrow;
  } catch (e) {
    throw BillScanException('The photo could not be read. Details: $e');
  } finally {
    await recognizer.close();
  }
}
