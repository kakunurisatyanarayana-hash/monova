import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'bill_scan_common.dart';
import 'bill_text_parser.dart';

/// Phone version: reads the photo with the on-device text recognizer (Android and iPhone). Nothing leaves the phone.
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
