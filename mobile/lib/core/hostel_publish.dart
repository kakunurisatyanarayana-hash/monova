import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cloud.dart';
import 'local_store.dart';
import 'public_complaints.dart';

/// Turns on QR complaints for a hostel. The owner's phone makes a random hostel code, and publishes
/// the hostel's name and owner in the shared store, so the complaint form knows where to send reports.
/// The code is kept on this phone, so the owner can print the room QR codes with it.
class HostelPublish {
  HostelPublish._();

  static const _codesKey = 'monova.hostelCodes';

  /// The code already made for [propertyId] on this phone, or null.
  static Future<String?> codeFor(String propertyId) async {
    final store = await LocalStore.open();
    for (final m in store.readList(_codesKey)) {
      if (m['property'] == propertyId) return '${m['code']}';
    }
    return null;
  }

  /// Every code on this phone, mapped to its property ID. Used to match shared complaints back to a property.
  static Future<Map<String, String>> propertyByCode() async {
    final store = await LocalStore.open();
    return {
      for (final m in store.readList(_codesKey))
        '${m['code']}': '${m['property']}',
    };
  }

  /// Publishes the hostel and returns its code. Throws a plain message when it cannot be done.
  static Future<String> publish({
    required String propertyId,
    required String name,
  }) async {
    if (!cloudReady) throw 'Cloud sync is not set up in this build.';
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw 'Sign in with your owner account first.';
    if (!user.emailVerified)
      throw 'Verify your email first, then turn on QR complaints.';
    final existing = await codeFor(propertyId);
    if (existing != null) return existing;
    await user.getIdToken(true);
    final code = newHostelCode(math.Random.secure());
    await FirebaseFirestore.instance.collection('hostels').doc(code).set({
      'name': name.trim(),
      'ownerUid': user.uid,
      'createdAt': DateTime.now().toIso8601String(),
    });
    final store = await LocalStore.open();
    final list = store.readList(_codesKey);
    await store.writeList(_codesKey, [
      ...list,
      {'code': code, 'property': propertyId},
    ]);
    return code;
  }
}
