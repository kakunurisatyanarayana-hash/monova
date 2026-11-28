import 'dart:js_interop';

import 'package:image_picker/image_picker.dart';

import 'bill_scan_common.dart';
import 'bill_text_parser.dart';

/// The parts of a Tesseract.js result that the app reads.
extension type TesseractData(JSObject _) implements JSObject {
  external JSString get text;
}

extension type TesseractResult(JSObject _) implements JSObject {
  external TesseractData get data;
}

/// Browser version: reads the photo with Tesseract.js, loaded from cdnjs in web/index.html. The photo is read in the browser.
@JS('Tesseract.recognize')
external JSPromise<TesseractResult> _tesseractRecognize(JSString image, JSString language);

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

  try {
    final result = await _tesseractRecognize(file.path.toJS, 'eng'.toJS).toDart;
    final parsed = parseBillText(result.data.text.toDart);
    if (parsed.isEmpty) {
      throw const BillScanException('The photo was read, but no date, amount or name was found. Try a flatter, brighter photo, or type the details.');
    }
    return parsed;
  } on BillScanException {
    rethrow;
  } catch (e) {
    throw BillScanException('The photo could not be read in this browser. Check the internet connection, or type the details. Details: $e');
  }
}
