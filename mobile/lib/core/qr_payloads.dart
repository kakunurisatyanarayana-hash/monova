import 'dart:convert';

/// Pure QR rules: what goes into each code, how big it can be, what a scanned code is, and guest check-in.
/// Nothing here touches the network or the camera.

/// Largest payload kept in one code. A QR code at medium error correction holds about 2,300 bytes;
/// this leaves a margin so codes scan easily on small screens.
const qrMaxBytes = 1800;

const invitePrefix = 'MONOVA-INV1:';
const guestPrefix = 'MONOVA-GUEST1:';

int payloadBytes(String payload) => utf8.encode(payload).length;

/// A message for a payload that is too large, or null when it fits.
String? qrTooLong(String payload) {
  final bytes = payloadBytes(payload);
  if (bytes <= qrMaxBytes) return null;
  return 'This is too much text for one QR code ($bytes bytes, the limit is $qrMaxBytes). '
      'Shorten the message or the schedule, or put the full invitation on a web page and make a QR code for its link.';
}

/// Escapes characters that have a meaning in Wi-Fi and contact codes.
String _escape(String s) {
  const special = r'\;,:"';
  final out = StringBuffer();
  for (final ch in s.split('')) {
    if (special.contains(ch)) out.write('\\');
    out.write(ch);
  }
  return out.toString();
}

/// Wi-Fi sharing code. Security is WPA (most networks), WEP, or nopass for open networks.
String wifiPayload({
  required String ssid,
  required String password,
  String security = 'WPA',
}) {
  final sec = security == 'nopass'
      ? 'nopass'
      : (security == 'WEP' ? 'WEP' : 'WPA');
  final pass = sec == 'nopass' ? '' : 'P:${_escape(password)};';
  return 'WIFI:T:$sec;S:${_escape(ssid)};$pass;';
}

/// Contact card (vCard 3.0), which phones offer to save.
String contactPayload({
  required String name,
  String phone = '',
  String email = '',
  String organisation = '',
}) {
  final lines = [
    'BEGIN:VCARD',
    'VERSION:3.0',
    'FN:${name.replaceAll('\n', ' ')}',
    if (organisation.isNotEmpty) 'ORG:${organisation.replaceAll('\n', ' ')}',
    if (phone.isNotEmpty) 'TEL:$phone',
    if (email.isNotEmpty) 'EMAIL:$email',
    'END:VCARD',
  ];
  return lines.join('\n');
}

/// True for latitude and longitude inside the world.
bool validCoordinates(double lat, double lng) =>
    lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

/// A map link that opens the place in whichever map app the phone uses. Works offline once the code is made.
String mapLinkPayload(double lat, double lng) =>
    'https://www.google.com/maps/search/?api=1&query=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';

/// A standard geo location code (geo:lat,lng) that map apps understand directly.
String geoPayload(double lat, double lng, {String label = ''}) {
  final base = 'geo:${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
  return label.trim().isEmpty
      ? base
      : '$base?q=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}(${label.trim()})';
}

/// A wedding or event invitation kept inside the code itself, so it works offline with no link.
class Invitation {
  const Invitation({
    required this.id,
    required this.bride,
    required this.groom,
    required this.date,
    required this.venue,
    this.address = '',
    this.timings = '',
    this.schedule = const [],
    this.message = '',
    this.latitude,
    this.longitude,
    this.template = 0,
  });

  final String id;
  final String bride;
  final String groom;
  final DateTime date;
  final String venue;
  final String address;
  final String timings;

  /// Events in order, for example "10:00 Muhurtham" or "19:30 Dinner".
  final List<String> schedule;
  final String message;
  final double? latitude;
  final double? longitude;

  /// Index into the template list in the screen (colours and layout).
  final int template;

  Invitation copyWith({String? message, int? template}) => Invitation(
    id: id,
    bride: bride,
    groom: groom,
    date: date,
    venue: venue,
    address: address,
    timings: timings,
    schedule: schedule,
    message: message ?? this.message,
    latitude: latitude,
    longitude: longitude,
    template: template ?? this.template,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'bride': bride,
    'groom': groom,
    'date': date.toIso8601String(),
    'venue': venue,
    'address': address,
    'timings': timings,
    'schedule': schedule,
    'message': message,
    'latitude': latitude,
    'longitude': longitude,
    'template': template,
  };

  factory Invitation.fromJson(Map<String, dynamic> j) => Invitation(
    id: '${j['id']}',
    bride: '${j['bride'] ?? ''}',
    groom: '${j['groom'] ?? ''}',
    date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
    venue: '${j['venue'] ?? ''}',
    address: '${j['address'] ?? ''}',
    timings: '${j['timings'] ?? ''}',
    schedule: [
      for (final s in (j['schedule'] as List<dynamic>? ?? const [])) '$s',
    ],
    message: '${j['message'] ?? ''}',
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    template: (j['template'] as num?)?.toInt() ?? 0,
  );
}

/// The code text for an invitation: a prefix and the invitation as compact JSON.
String invitationPayload(Invitation inv) =>
    '$invitePrefix${jsonEncode(inv.toJson())}';

/// Reads an invitation code back. Returns null when the text is not an invitation code.
Invitation? parseInvitationPayload(String text) {
  if (!text.startsWith(invitePrefix)) return null;
  try {
    final j = jsonDecode(text.substring(invitePrefix.length));
    if (j is! Map) return null;
    return Invitation.fromJson(Map<String, dynamic>.from(j));
  } catch (_) {
    return null;
  }
}

/// A guest on an event's list, with check-in status and an optional RSVP.
class GuestRecord {
  const GuestRecord({
    required this.id,
    required this.eventId,
    required this.name,
    this.phone = '',
    this.rsvp = 'unknown',
    this.checkedInAt,
    this.people = 1,
  });

  final String id;
  final String eventId;
  final String name;
  final String phone;

  /// 'unknown', 'yes' or 'no'.
  final String rsvp;
  final DateTime? checkedInAt;

  /// How many people this invitation admits.
  final int people;

  bool get checkedIn => checkedInAt != null;

  GuestRecord copyWith({
    String? name,
    String? phone,
    String? rsvp,
    DateTime? checkedInAt,
    bool clearCheckIn = false,
    int? people,
  }) => GuestRecord(
    id: id,
    eventId: eventId,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    rsvp: rsvp ?? this.rsvp,
    checkedInAt: clearCheckIn ? null : (checkedInAt ?? this.checkedInAt),
    people: people ?? this.people,
  );

  /// The code text for this guest: the event and the guest, nothing else.
  String get payload => '$guestPrefix$eventId:$id';

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventId': eventId,
    'name': name,
    'phone': phone,
    'rsvp': rsvp,
    'checkedInAt': checkedInAt?.toIso8601String(),
    'people': people,
  };

  factory GuestRecord.fromJson(Map<String, dynamic> j) => GuestRecord(
    id: '${j['id']}',
    eventId: '${j['eventId']}',
    name: '${j['name'] ?? ''}',
    phone: '${j['phone'] ?? ''}',
    rsvp: const {'unknown', 'yes', 'no'}.contains(j['rsvp'])
        ? '${j['rsvp']}'
        : 'unknown',
    checkedInAt: DateTime.tryParse('${j['checkedInAt']}'),
    people: (j['people'] as num?)?.toInt() ?? 1,
  );
}

/// A guest code read from a scan: which event and which guest.
({String eventId, String guestId})? parseGuestPayload(String text) {
  if (!text.startsWith(guestPrefix)) return null;
  final rest = text.substring(guestPrefix.length);
  final parts = rest.split(':');
  if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) return null;
  return (eventId: parts[0], guestId: parts[1]);
}

enum CheckInOutcome { checkedIn, alreadyCheckedIn, notOnList }

class CheckInResult {
  const CheckInResult(this.outcome, this.guests, {this.guest});

  final CheckInOutcome outcome;

  /// The guest list after the check-in (unchanged unless the outcome is [CheckInOutcome.checkedIn]).
  final List<GuestRecord> guests;

  /// The guest the code refers to, when found.
  final GuestRecord? guest;
}

/// Checks a guest in once. A second scan of the same code is reported, never recorded again.
CheckInResult checkInGuest(
  List<GuestRecord> guests,
  String eventId,
  String guestId,
  DateTime now,
) {
  final index = guests.indexWhere(
    (g) => g.eventId == eventId && g.id == guestId,
  );
  if (index < 0) return CheckInResult(CheckInOutcome.notOnList, guests);
  final guest = guests[index];
  if (guest.checkedIn)
    return CheckInResult(CheckInOutcome.alreadyCheckedIn, guests, guest: guest);
  final updated = guest.copyWith(checkedInAt: now);
  return CheckInResult(CheckInOutcome.checkedIn, [
    for (var i = 0; i < guests.length; i++) i == index ? updated : guests[i],
  ], guest: updated);
}

/// Attendance figures for one event.
class AttendanceSummary {
  const AttendanceSummary({
    required this.invited,
    required this.checkedIn,
    required this.peopleInvited,
    required this.peopleIn,
    required this.yes,
    required this.no,
    required this.unknown,
  });

  final int invited;
  final int checkedIn;
  final int peopleInvited;
  final int peopleIn;
  final int yes;
  final int no;
  final int unknown;
}

AttendanceSummary attendanceFor(List<GuestRecord> guests, String eventId) {
  final list = [
    for (final g in guests)
      if (g.eventId == eventId) g,
  ];
  return AttendanceSummary(
    invited: list.length,
    checkedIn: list.where((g) => g.checkedIn).length,
    peopleInvited: list.fold(0, (s, g) => s + g.people),
    peopleIn: list.where((g) => g.checkedIn).fold(0, (s, g) => s + g.people),
    yes: list.where((g) => g.rsvp == 'yes').length,
    no: list.where((g) => g.rsvp == 'no').length,
    unknown: list.where((g) => g.rsvp == 'unknown').length,
  );
}

/// What a scanned code is, and whether it may be opened. Nothing is opened automatically; the user confirms.
enum ScanKind { invitation, guest, web, location, wifi, contact, text, unsafe }

class ScanInfo {
  const ScanInfo(
    this.kind,
    this.title,
    this.detail, {
    this.openable = false,
    this.url,
  });

  final ScanKind kind;
  final String title;
  final String detail;

  /// True only for plain web links, after the user confirms.
  final bool openable;
  final String? url;
}

/// Works out what a scanned text is. Only http and https links can be opened; anything with another
/// address scheme (javascript:, intent:, file:, data:) is reported as unsafe and never opened.
ScanInfo classifyScan(String raw) {
  final text = raw.trim();
  if (text.startsWith(invitePrefix)) {
    final inv = parseInvitationPayload(text);
    return inv == null
        ? const ScanInfo(
            ScanKind.unsafe,
            'Damaged invitation code',
            'This invitation code could not be read.',
          )
        : ScanInfo(
            ScanKind.invitation,
            'Invitation: ${inv.bride} & ${inv.groom}',
            '${inv.venue} · ${inv.date.day}/${inv.date.month}/${inv.date.year}',
          );
  }
  if (text.startsWith(guestPrefix)) {
    return ScanInfo(
      ScanKind.guest,
      'Guest entry code',
      'Check this guest in at the entrance.',
    );
  }
  if (text.startsWith('WIFI:')) {
    final ssid =
        RegExp(r'S:([^;]*)').firstMatch(text)?.group(1) ?? 'Wi-Fi network';
    return ScanInfo(
      ScanKind.wifi,
      'Wi-Fi: $ssid',
      'Joins this Wi-Fi network after you confirm and enter the password.',
    );
  }
  if (text.startsWith('BEGIN:VCARD')) {
    final name =
        RegExp(r'FN:(.*)').firstMatch(text)?.group(1)?.trim() ?? 'Contact';
    return ScanInfo(
      ScanKind.contact,
      'Contact: $name',
      'Save this contact to your phone.',
    );
  }
  if (text.startsWith('geo:')) {
    return ScanInfo(
      ScanKind.location,
      'Location',
      text,
      openable: true,
      url: text,
    );
  }
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'http' || scheme == 'https') {
      return ScanInfo(
        ScanKind.web,
        'Web link',
        uri.host,
        openable: true,
        url: text,
      );
    }
    return ScanInfo(
      ScanKind.unsafe,
      'Not opened: unknown link type',
      'This code starts with "$scheme:". It was not opened for your safety.',
    );
  }
  return ScanInfo(ScanKind.text, 'Text', text);
}
