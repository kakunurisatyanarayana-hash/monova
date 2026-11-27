// What may be sent to the shared Firestore store. Pure Dart, so the rule can be tested without a network.
//
// Approved: hostel ID, room and floor, ticket ID, category and description, status and timestamps,
// resolution comments, and review rating and feedback.
// Never sent: resident name, phone number, email, financial information, attachments.

import 'complaints.dart';

Map<String, dynamic> complaintCloudDoc(
  Complaint c, {
  required String ownerUid,
}) => {
  'hostel': c.propertyId,
  'ticket': c.ticket,
  'room': c.roomNumber,
  'floor': c.floor,
  'category': c.category,
  'description': c.description,
  'status': c.status.name,
  'createdAt': c.createdAt.toIso8601String(),
  'updatedAt': (c.updatedAt ?? c.createdAt).toIso8601String(),
  'resolution': c.resolution,
  'ownerUid': ownerUid,
};

Map<String, dynamic> feedbackCloudDoc(
  ResidentFeedback f, {
  required String ownerUid,
}) => {
  'hostel': f.propertyId,
  'kind': f.kind.name,
  'rating': f.rating,
  'text': f.text,
  'createdAt': f.createdAt.toIso8601String(),
  'ownerUid': ownerUid,
};

/// Keys that must never appear in a cloud document.
const forbiddenCloudKeys = <String>{
  'resident',
  'residentName',
  'phone',
  'email',
  'name',
  'amount',
  'rent',
  'payment',
  'idNumber',
};
