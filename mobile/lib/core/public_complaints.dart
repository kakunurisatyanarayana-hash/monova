// The public complaint form that a room QR code opens. Pure Dart, no network, so the rules can be tested.
//
// A resident needs no app and no account. They give the room (from the QR code), a category and the problem.
// They do not give their name or phone: the approval keeps resident contact details on the phone.
// The form returns a reference and a status link. The status link carries a random token, which is also the
// document ID in the shared store, so nobody can browse other complaints by guessing references.

import 'dart:math' as math;

import 'complaints.dart';

const complaintFormRoute = '/complain';
const trackRoute = '/track';

/// Letters and digits without look-alikes (no 0, O, 1, I or l).
const _alphabet = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Random token of 24 characters: the document ID and the tracking link. Long enough that it cannot be guessed.
String newTrackToken(math.Random random) => String.fromCharCodes([for (var i = 0; i < 24; i++) _alphabet.codeUnitAt(random.nextInt(_alphabet.length))]);

/// Short code for a hostel, used in the QR link. Random, so the link does not reveal the owner.
String newHostelCode(math.Random random) => String.fromCharCodes([for (var i = 0; i < 8; i++) _alphabet.codeUnitAt(random.nextInt(_alphabet.length))]);

/// The problem with what the resident typed, or null when it can be sent. Same limits as the shared-store rules.
String? publicComplaintProblem({required String room, required String category, required String description}) {
  if (room.trim().isEmpty || room.trim().length > 12) return 'The room number is missing.';
  if (!complaintCategories.contains(category)) return 'Choose a category.';
  final d = description.trim();
  if (d.length < 5) return 'Describe the problem in a few words.';
  if (d.length > 1000) return 'Keep the description under 1000 characters.';
  if (RegExp(r'(.)\1{7,}').hasMatch(d)) return 'That text looks like a mistake. Please write it again.';
  return null;
}

/// The link printed on the room's QR code. [base] is the address the web app is published at.
String complaintFormLink(String base, {required String code, required String room, required int floor}) =>
    '${_trim(base)}/#$complaintFormRoute?h=$code&r=${Uri.encodeComponent(room)}&f=$floor';

/// The status link given to the resident after they send a complaint.
String trackLink(String base, String token) => '${_trim(base)}/#$trackRoute?t=$token';

String _trim(String base) => base.endsWith('/') ? base.substring(0, base.length - 1) : base;

/// Reads the room, floor and hostel code from the form link's query. Null for a link that is incomplete.
({String code, String room, int floor})? readFormQuery(Map<String, String> query) {
  final code = query['h'] ?? '';
  final room = query['r'] ?? '';
  final floor = int.tryParse(query['f'] ?? '');
  if (code.length != 8 || room.isEmpty || floor == null) return null;
  return (code: code, room: room, floor: floor);
}

/// A short reference for the resident to quote, such as MN-7K3Q.
String publicTicket(math.Random random) => 'MN-${String.fromCharCodes([for (var i = 0; i < 4; i++) _alphabet.codeUnitAt(random.nextInt(_alphabet.length))]).toUpperCase()}';
