import 'bill_text_parser.dart';

class BillScanException implements Exception {
  const BillScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reads the date, final amount and biller from a photo of a bill.
/// The phone build with the text reader fills this in. Builds without it say so, and the user types the details.
Future<ParsedBill> scanBillPhoto({required bool camera}) async {
  throw const BillScanException(
    'Reading a bill photo needs the text reader, which is in the next phone build. For now, type the date, biller and price.',
  );
}
