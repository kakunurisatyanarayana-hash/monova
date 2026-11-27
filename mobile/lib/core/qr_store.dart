import 'local_store.dart';
import 'qr_payloads.dart';

const invitationsKey = 'monova.invitations';
const guestsKey = 'monova.guests';

/// Invitations and guest lists kept on this phone. Nothing is registered or sent anywhere.
class QrStore {
  QrStore._();

  static Future<List<Invitation>> loadInvitations() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(invitationsKey)) Invitation.fromJson(m)];
  }

  static Future<void> saveInvitations(List<Invitation> list) async {
    final store = await LocalStore.open();
    await store.writeList(invitationsKey, [for (final i in list) i.toJson()]);
  }

  static Future<List<GuestRecord>> loadGuests() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(guestsKey)) GuestRecord.fromJson(m)];
  }

  static Future<void> saveGuests(List<GuestRecord> list) async {
    final store = await LocalStore.open();
    await store.writeList(guestsKey, [for (final g in list) g.toJson()]);
  }
}
