import 'package:flutter_test/flutter_test.dart';
import 'package:monova_app/core/qr_payloads.dart';

void main() {
  final inv = Invitation(
    id: 'w1',
    bride: 'Asha',
    groom: 'Ravi',
    date: DateTime(2026, 12, 12),
    venue: 'Garden Hall',
    address: 'Main Road, Amarsia',
    timings: '10:00 onwards',
    schedule: const ['10:00 Muhurtham', '19:30 Dinner'],
    message: 'Please join us.',
    latitude: 17.385,
    longitude: 78.4867,
  );

  test('an invitation survives the code round trip, with its schedule and location', () {
    final text = invitationPayload(inv);
    expect(text.startsWith(invitePrefix), isTrue);
    final back = parseInvitationPayload(text)!;
    expect(back.bride, 'Asha');
    expect(back.schedule, ['10:00 Muhurtham', '19:30 Dinner']);
    expect(back.latitude, closeTo(17.385, 1e-9));
    expect(back.date, DateTime(2026, 12, 12));
  });

  test('a long invitation is refused with a helpful message rather than making an unreadable code', () {
    final long = inv.copyWith(message: 'x' * 2500);
    expect(qrTooLong(invitationPayload(long)), contains('too much text'));
    expect(qrTooLong(invitationPayload(inv)), isNull);
  });

  test('Wi-Fi codes escape special characters and open networks have no password', () {
    expect(wifiPayload(ssid: 'Home;Net', password: r'p:ss,w\rd'), r'WIFI:T:WPA;S:Home\;Net;P:p\:ss\,w\\rd;;');
    expect(wifiPayload(ssid: 'Guest', password: '', security: 'nopass'), 'WIFI:T:nopass;S:Guest;;');
  });

  test('a contact card is a valid vCard with the name and number', () {
    final card = contactPayload(name: 'Ravi Kumar', phone: '+919505323902');
    expect(card, contains('BEGIN:VCARD'));
    expect(card, contains('FN:Ravi Kumar'));
    expect(card, contains('TEL:+919505323902'));
  });

  test('coordinates are checked, and location codes carry them', () {
    expect(validCoordinates(17.3, 78.4), isTrue);
    expect(validCoordinates(95, 0), isFalse);
    expect(geoPayload(17.385, 78.4867), 'geo:17.385000,78.486700');
    expect(mapLinkPayload(17.385, 78.4867), contains('query=17.385000,78.486700'));
  });

  test('guest check-in records once and refuses a second scan of the same code', () {
    final now = DateTime(2026, 12, 12, 18, 5);
    final guests = [
      const GuestRecord(id: 'g1', eventId: 'w1', name: 'Mohan', people: 2),
      const GuestRecord(id: 'g2', eventId: 'w1', name: 'Lakshmi'),
    ];
    final first = checkInGuest(guests, 'w1', 'g1', now);
    expect(first.outcome, CheckInOutcome.checkedIn);
    expect(first.guests.first.checkedIn, isTrue);

    final again = checkInGuest(first.guests, 'w1', 'g1', now.add(const Duration(minutes: 2)));
    expect(again.outcome, CheckInOutcome.alreadyCheckedIn);
    expect(again.guests.first.checkedInAt, now, reason: 'the first time is kept');

    expect(checkInGuest(guests, 'other', 'g1', now).outcome, CheckInOutcome.notOnList);
  });

  test('attendance counts invited people, people in, and the RSVP answers', () {
    final guests = [
      const GuestRecord(id: 'a', eventId: 'w1', name: 'A', people: 3, rsvp: 'yes', checkedInAt: null),
      GuestRecord(id: 'b', eventId: 'w1', name: 'B', rsvp: 'no', checkedInAt: DateTime(2026, 12, 12)),
      const GuestRecord(id: 'c', eventId: 'w2', name: 'C'),
    ];
    final s = attendanceFor(guests, 'w1');
    expect(s.invited, 2);
    expect(s.checkedIn, 1);
    expect(s.peopleInvited, 4);
    expect(s.peopleIn, 1);
    expect(s.yes, 1);
    expect(s.no, 1);
  });

  test('guest codes are read back to their event and guest', () {
    const g = GuestRecord(id: 'g9', eventId: 'w1', name: 'Mohan');
    final parsed = parseGuestPayload(g.payload)!;
    expect(parsed.eventId, 'w1');
    expect(parsed.guestId, 'g9');
    expect(parseGuestPayload('MONOVA-GUEST1:w1'), isNull);
  });

  test('scanned links: only web and map links may be opened, and dangerous schemes never are', () {
    expect(classifyScan('https://example.com/invite').openable, isTrue);
    expect(classifyScan('geo:17.385,78.4867').openable, isTrue);
    expect(classifyScan('javascript:alert(1)').kind, ScanKind.unsafe);
    expect(classifyScan('javascript:alert(1)').openable, isFalse);
    expect(classifyScan('intent://scan/#Intent;end').kind, ScanKind.unsafe);
    expect(classifyScan('file:///storage/secret').kind, ScanKind.unsafe);
  });

  test('scanned Wi-Fi, contact and plain text codes are described, not opened', () {
    expect(classifyScan('WIFI:T:WPA;S:Home;P:x;;').kind, ScanKind.wifi);
    expect(classifyScan('WIFI:T:WPA;S:Home;P:x;;').openable, isFalse);
    expect(classifyScan(contactPayload(name: 'Ravi')).kind, ScanKind.contact);
    expect(classifyScan('Hello there').kind, ScanKind.text);
    expect(classifyScan(invitePrefix + 'not json').kind, ScanKind.unsafe);
  });
}
