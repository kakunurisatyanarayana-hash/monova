// One scanner for every platform: the phone uses the on-device reader, the browser uses Tesseract.js.
export 'bill_scan_common.dart';
export 'bill_ocr_io.dart' if (dart.library.js_interop) 'bill_ocr_web.dart';
