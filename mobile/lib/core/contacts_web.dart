import 'contacts_picker.dart';

/// Browsers do not give access to contacts, so the web build tells the user to use the phone app.
Future<List<PickedContact>> loadContacts() async {
  throw const ContactsException('Picking people from contacts works in the phone app. Type the names here instead.');
}
