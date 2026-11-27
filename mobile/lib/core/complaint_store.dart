import 'complaints.dart';
import 'local_store.dart';

/// Saves complaints and feedback on this phone. Nothing is sent anywhere.
class ComplaintStore {
  ComplaintStore._();

  static Future<List<Complaint>> loadComplaints() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(complaintsKey)) ?Complaint.fromJson(m)];
  }

  static Future<void> saveComplaints(List<Complaint> list) async {
    final store = await LocalStore.open();
    await store.writeList(complaintsKey, [for (final c in list) c.toJson()]);
  }

  static Future<List<ResidentFeedback>> loadFeedback() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(feedbackKey)) ?ResidentFeedback.fromJson(m)];
  }

  static Future<void> saveFeedback(List<ResidentFeedback> list) async {
    final store = await LocalStore.open();
    await store.writeList(feedbackKey, [for (final f in list) f.toJson()]);
  }
}
