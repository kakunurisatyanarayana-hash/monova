/// Reads people from the phone's contacts. Only the browser build uses the fallback, which refuses politely.
library;

export 'contacts_web.dart' if (dart.library.io) 'contacts_mobile.dart';

class PickedContact {
  const PickedContact({required this.name, required this.phone});

  final String name;
  final String phone;
}

class ContactsException implements Exception {
  const ContactsException(this.message);

  final String message;

  @override
  String toString() => message;
}
