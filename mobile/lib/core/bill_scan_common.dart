/// A problem reading a bill photo, with a message the user can act on.
class BillScanException implements Exception {
  const BillScanException(this.message);

  final String message;

  @override
  String toString() => message;
}
