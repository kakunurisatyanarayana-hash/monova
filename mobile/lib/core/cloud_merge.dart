// Brings shared complaints (from the Firestore store) into this phone's list. Pure Dart, so it can be tested.
//
// Rules:
// - A shared complaint this phone does not have is added. Its resident name and phone are empty, because they
//   are never shared; the source says it came from another phone.
// - A complaint this phone already has keeps its own name, phone, description and history. Only the status,
//   resolution and update time are taken from the shared copy, and only when the shared copy is newer.
// - Nothing is deleted here.

import 'complaints.dart';

Complaint? complaintFromCloud(Map<String, dynamic> d) {
  final created = DateTime.tryParse('${d['createdAt']}');
  final ticket = '${d['ticket'] ?? ''}';
  if (created == null || ticket.isEmpty) return null;
  final status = ComplaintStatus.values.where((s) => s.name == '${d['status']}').firstOrNull ?? ComplaintStatus.open;
  return Complaint(
    id: ticket,
    ticket: ticket,
    propertyId: '${d['hostel'] ?? ''}',
    roomNumber: '${d['room'] ?? ''}',
    floor: (d['floor'] as num?)?.toInt() ?? 0,
    residentName: '',
    residentPhone: '',
    category: '${d['category'] ?? 'Other'}',
    description: '${d['description'] ?? ''}',
    source: 'Shared from another phone',
    createdAt: created,
    status: status,
    resolution: '${d['resolution'] ?? ''}',
    updatedAt: DateTime.tryParse('${d['updatedAt']}'),
  );
}

/// Merges the shared copies into the local list. Returns the new list and how many complaints changed.
({List<Complaint> complaints, int added, int updated}) mergeSharedComplaints(List<Complaint> local, List<Map<String, dynamic>> remote) {
  final byTicket = {for (final c in local) c.ticket: c};
  var added = 0;
  var updated = 0;
  for (final d in remote) {
    final shared = complaintFromCloud(d);
    if (shared == null) continue;
    final mine = byTicket[shared.ticket];
    if (mine == null) {
      byTicket[shared.ticket] = shared;
      added++;
      continue;
    }
    final sharedTime = shared.updatedAt;
    final localTime = mine.updatedAt ?? mine.createdAt;
    if (sharedTime == null || !sharedTime.isAfter(localTime)) continue;
    if (shared.status == mine.status && shared.resolution == mine.resolution) continue;
    byTicket[shared.ticket] = mine.copyWith(
      status: shared.status,
      resolution: shared.resolution,
      updatedAt: sharedTime,
    );
    updated++;
  }
  final list = byTicket.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return (complaints: list, added: added, updated: updated);
}
