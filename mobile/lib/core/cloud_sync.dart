import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'cloud.dart';
import 'cloud_docs.dart';
import 'cloud_merge.dart';
import 'hostel_publish.dart';
import 'complaint_store.dart';
import 'complaints.dart';
import 'local_store.dart';

/// Uploads complaints to the shared Firestore store, only when Firebase is set up and the owner has a verified account.
/// Anything not uploaded stays on the phone, marked pending, and is retried the next time sync runs.
class CloudSync {
  CloudSync._();

  static const _pendingKey = 'monova.cloud.pendingComplaints';

  /// Why nothing can be synced right now, or null when sync can run.
  static String? blockedReason() {
    if (!CloudConfig.isSet) return 'Cloud sync is not set up in this build. Everything keeps working on this phone.';
    if (!cloudReady) return 'Cloud sync could not start on this phone. Everything keeps working on this phone.';
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 'Sign in with your owner account to share complaints.';
    if (!user.emailVerified) return 'Verify your email first. Check your inbox, then press "I have verified".';
    return null;
  }

  /// Marks a complaint as waiting to be uploaded. Called whenever a complaint is saved.
  static Future<void> markPending(String ticket) async {
    final store = await LocalStore.open();
    final current = store.readList(_pendingKey).map((m) => '${m['ticket']}').toSet();
    current.add(ticket);
    await store.writeList(_pendingKey, [for (final t in current) {'ticket': t}]);
  }

  static Future<int> pendingCount() async {
    final store = await LocalStore.open();
    return store.readList(_pendingKey).length;
  }

  /// Uploads every pending complaint. Returns the number uploaded. Never throws; the reason is in [lastError].
  static Future<int> pushPending({required void Function(String message) report}) async {
    final reason = blockedReason();
    if (reason != null) {
      report(reason);
      return 0;
    }
    final user = FirebaseAuth.instance.currentUser!;
    // Refresh the sign-in token first, so the store sees the current verified-email status.
    await user.getIdToken(true);
    final store = await LocalStore.open();
    final pending = store.readList(_pendingKey).map((m) => '${m['ticket']}').toList();
    if (pending.isEmpty) return 0;
    final all = await ComplaintStore.loadComplaints();
    var sent = 0;
    final keep = <String>[];
    var failed = false;
    for (final ticket in pending) {
      // After the first failure, keep the rest for the next attempt instead of repeating the same error.
      if (failed) {
        keep.add(ticket);
        continue;
      }
      final match = [for (final c in all) if (c.ticket == ticket) c];
      if (match.isEmpty) continue;
      try {
        await FirebaseFirestore.instance
            .collection('complaints')
            .doc(ticket)
            .set(complaintCloudDoc(match.first, ownerUid: user.uid), SetOptions(merge: true));
        sent++;
      } on FirebaseException catch (e) {
        keep.add(ticket);
        failed = true;
        report(_explain(e));
      }
    }
    await store.writeList(_pendingKey, [for (final t in keep) {'ticket': t}]);
    if (sent > 0 && !failed) report('$sent complaint${sent == 1 ? '' : 's'} shared.');
    return sent;
  }

  /// Downloads this owner's shared complaints and merges them into this phone. Returns (added, updated), or null on failure.
  static Future<({int added, int updated})?> pullOwnerComplaints({required void Function(String message) report}) async {
    final reason = blockedReason();
    if (reason != null) {
      report(reason);
      return null;
    }
    final user = FirebaseAuth.instance.currentUser!;
    try {
      await user.getIdToken(true);
      final snap = await FirebaseFirestore.instance.collection('complaints').where('ownerUid', isEqualTo: user.uid).get();
      // Complaints from the QR form carry the hostel code. Match them to the property on this phone when it is known.
      final byCode = await HostelPublish.propertyByCode();
      final remote = [
        for (final d in snap.docs)
          {...d.data(), 'hostel': byCode[d.data()['hostel']] ?? d.data()['hostel']},
      ];
      final local = await ComplaintStore.loadComplaints();
      final merged = mergeSharedComplaints(local, remote);
      await ComplaintStore.saveComplaints(merged.complaints);
      if (merged.added > 0 || merged.updated > 0) {
        report('${merged.added} new and ${merged.updated} updated complaint${merged.added + merged.updated == 1 ? '' : 's'} from the shared store.');
      } else {
        report('Shared complaints are up to date.');
      }
      return (added: merged.added, updated: merged.updated);
    } on FirebaseException catch (e) {
      report(_explain(e));
      return null;
    }
  }

  static String _explain(FirebaseException e) {
    return switch (e.code) {
      'resource-exhausted' => 'The free shared-storage limit for today is reached. Your complaints are saved on this phone and will be shared later. Nothing was charged.',
      'unavailable' || 'deadline-exceeded' => 'No connection to the shared store. Complaints stay on this phone and are shared when the connection returns.',
      'permission-denied' => 'The shared store refused this account. Check that the owner account is verified and set up for this hostel.',
      _ => 'Sharing did not finish (${e.code}). Complaints stay on this phone and will be retried.',
    };
  }
}

/// Runs sync by itself: at app start, when the app returns to the foreground, and when the Complaints screen opens.
/// It uploads what is waiting, then downloads the owner's complaints. It runs at most every five minutes,
/// never twice at once, and does nothing when the owner is not signed in and verified. Problems stay silent here;
/// the Owner account screen shows them when it is open.
class AutoSync {
  AutoSync._();

  static const interval = Duration(minutes: 5);
  static DateTime? _lastRun;
  static bool _running = false;

  static Future<void> run({bool force = false}) async {
    if (CloudSync.blockedReason() != null || _running) return;
    final now = DateTime.now();
    if (!force && _lastRun != null && now.difference(_lastRun!) < interval) return;
    _running = true;
    try {
      await CloudSync.pushPending(report: (_) {});
      await CloudSync.pullOwnerComplaints(report: (_) {});
      _lastRun = DateTime.now();
    } finally {
      _running = false;
    }
  }

  /// Waits until Firebase has restored the signed-in account, then syncs once.
  static Future<void> atStart() async {
    if (!cloudReady) return;
    await FirebaseAuth.instance.authStateChanges().first;
    await run();
  }
}

/// Registers a new complaint as pending and tries to share it. Safe to call without a connection.
Future<void> queueComplaintForSync(Complaint c, void Function(String) report) async {
  await CloudSync.markPending(c.ticket);
  await CloudSync.pushPending(report: report);
}

/// Owner account actions. All return a plain message the screen can show.
class OwnerAccount {
  OwnerAccount._();

  static User? get user => cloudReady ? FirebaseAuth.instance.currentUser : null;

  static Future<String> register(String email, String password) async {
    final blocked = CloudConfig.isSet && cloudReady ? null : CloudSync.blockedReason();
    if (blocked != null) return blocked;
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.trim(), password: password);
      await cred.user?.sendEmailVerification();
      return 'Account created. We sent a verification link to ${email.trim()}. Open it, then press "I have verified".';
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    }
  }

  static Future<String> signIn(String email, String password) async {
    final blocked = CloudConfig.isSet && cloudReady ? null : CloudSync.blockedReason();
    if (blocked != null) return blocked;
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password);
      return FirebaseAuth.instance.currentUser!.emailVerified
          ? 'Signed in.'
          : 'Signed in, but the email is not verified yet. Verify it to share complaints.';
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    }
  }

  static Future<String> resendVerification() async {
    final u = user;
    if (u == null) return 'Sign in first.';
    try {
      await u.sendEmailVerification();
      return 'Verification email sent again to ${u.email}.';
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    }
  }

  static Future<String> checkVerified() async {
    final u = user;
    if (u == null) return 'Sign in first.';
    await u.reload();
    // The verified flag reaches the store only through a fresh sign-in token.
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
    return FirebaseAuth.instance.currentUser!.emailVerified ? 'Email verified. Complaints can now be shared.' : 'Not verified yet. Open the link in your email, then try again.';
  }

  static Future<String> resetPassword(String email) async {
    if (!cloudReady) return CloudSync.blockedReason() ?? 'Cloud sync is not available.';
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return 'If an account exists for ${email.trim()}, a reset link has been sent.';
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    }
  }

  static Future<void> signOut() async {
    if (cloudReady) await FirebaseAuth.instance.signOut();
  }

  static String _authMessage(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'Enter a valid email address.',
        'email-already-in-use' => 'An account already exists for this email. Sign in instead.',
        'weak-password' => 'Use a password of at least 6 characters.',
        'invalid-credential' || 'wrong-password' || 'user-not-found' => 'The email or password is not right.',
        'too-many-requests' => 'Too many attempts. Wait a few minutes and try again.',
        'network-request-failed' => 'No internet connection. Your data stays on this phone.',
        _ => 'The account action did not finish (${e.code}).',
      };
}
