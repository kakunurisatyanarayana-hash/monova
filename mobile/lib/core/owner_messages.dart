import 'whatsapp_messages.dart';

/// The welcome message with the room's complaint link, sent by the owner from WhatsApp.
String welcomeWithComplaintLink({
  required String hostel,
  required String resident,
  required String room,
  required String link,
}) =>
    '${welcomeMessage(hostel: hostel, resident: resident, room: room)}\n'
    'To report a problem, open this link: $link';

/// One person's share of a bill, in paise. The remainder goes one paisa at a time to the first people,
/// so the shares always add up to the total.
List<int> splitEqually(int totalCents, int people) {
  if (people <= 0 || totalCents < 0) return const [];
  final base = totalCents ~/ people;
  final remainder = totalCents % people;
  return [for (var i = 0; i < people; i++) base + (i < remainder ? 1 : 0)];
}

/// The message for one person's share of a split bill.
String billShareMessage({
  required String hostel,
  required String resident,
  required String label,
  required String share,
}) {
  final what = label.trim().isEmpty ? 'the bill' : label.trim();
  return 'Hello $resident, your share of $what at $hostel is $share. Thank you.';
}
