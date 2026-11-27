// Hostel complaints, resident feedback and the WhatsApp links that carry them. Pure Dart, no network.
//
// Residents do not need Monova. A complaint reaches the owner in one of three ways:
//  - a room QR code, which opens WhatsApp with the room already in the message (no server needed);
//  - a WhatsApp message the resident sends to the hostel number;
//  - an entry the owner makes in Monova from either of those.
// Replies go back to the resident by WhatsApp too. Nothing is sent by Monova itself.

import 'dart:math' as math;

const complaintsKey = 'monova.property.complaints';
const feedbackKey = 'monova.property.feedback';

/// Categories a complaint can belong to.
const complaintCategories = <String>[
  'Plumbing',
  'Electricity',
  'Wi-Fi',
  'Cleaning',
  'Bathroom',
  'Water supply',
  'Furniture',
  'Food',
  'Security',
  'Other',
];

enum ComplaintStatus { open, acknowledged, inProgress, resolved, closed }

String complaintStatusLabel(ComplaintStatus s) => switch (s) {
  ComplaintStatus.open => 'Open',
  ComplaintStatus.acknowledged => 'Acknowledged',
  ComplaintStatus.inProgress => 'In progress',
  ComplaintStatus.resolved => 'Resolved',
  ComplaintStatus.closed => 'Closed',
};

/// Where the complaint came from, so the owner knows how it arrived.
const complaintSources = <String>[
  'WhatsApp message',
  'Room QR code',
  'Monova app',
  'Phone call',
  'In person',
];

/// One change of status, kept with its time, so the history can be shown.
class StatusChange {
  const StatusChange({
    required this.at,
    required this.from,
    required this.to,
    this.note = '',
  });

  final DateTime at;
  final ComplaintStatus? from;
  final ComplaintStatus to;
  final String note;

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'from': from?.name,
    'to': to.name,
    'note': note,
  };

  static StatusChange? fromJson(Map<String, dynamic> j) {
    final at = DateTime.tryParse('${j['at']}');
    final to = _statusNamed('${j['to']}');
    if (at == null || to == null) return null;
    return StatusChange(
      at: at,
      from: _statusNamed('${j['from']}'),
      to: to,
      note: '${j['note'] ?? ''}',
    );
  }
}

class Complaint {
  const Complaint({
    required this.id,
    required this.ticket,
    required this.propertyId,
    required this.roomNumber,
    required this.floor,
    required this.residentName,
    required this.residentPhone,
    required this.category,
    required this.description,
    required this.source,
    required this.createdAt,
    this.status = ComplaintStatus.open,
    this.assignedTo = '',
    this.internalNotes = const [],
    this.resolution = '',
    this.history = const [],
    this.updatedAt,
  });

  final String id;

  /// The reference the resident quotes, for example MN-7K3Q.
  final String ticket;
  final String propertyId;
  final String roomNumber;

  /// The floor number as stored by the property (0 ground, 1 first, -1 basement).
  final int floor;
  final String residentName;
  final String residentPhone;
  final String category;
  final String description;
  final String source;
  final DateTime createdAt;
  final ComplaintStatus status;
  final String assignedTo;

  /// Notes only the owner and staff see. Each has its time.
  final List<StatusChange> internalNotes;
  final String resolution;
  final List<StatusChange> history;
  final DateTime? updatedAt;

  bool get isOpen =>
      status == ComplaintStatus.open ||
      status == ComplaintStatus.acknowledged ||
      status == ComplaintStatus.inProgress;

  Complaint copyWith({
    ComplaintStatus? status,
    String? assignedTo,
    List<StatusChange>? internalNotes,
    String? resolution,
    List<StatusChange>? history,
    DateTime? updatedAt,
  }) => Complaint(
    id: id,
    ticket: ticket,
    propertyId: propertyId,
    roomNumber: roomNumber,
    floor: floor,
    residentName: residentName,
    residentPhone: residentPhone,
    category: category,
    description: description,
    source: source,
    createdAt: createdAt,
    status: status ?? this.status,
    assignedTo: assignedTo ?? this.assignedTo,
    internalNotes: internalNotes ?? this.internalNotes,
    resolution: resolution ?? this.resolution,
    history: history ?? this.history,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ticket': ticket,
    'property': propertyId,
    'room': roomNumber,
    'floor': floor,
    'resident': residentName,
    'phone': residentPhone,
    'category': category,
    'description': description,
    'source': source,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'assignedTo': assignedTo,
    'internalNotes': [for (final n in internalNotes) n.toJson()],
    'resolution': resolution,
    'history': [for (final h in history) h.toJson()],
    'updatedAt': updatedAt?.toIso8601String(),
  };

  static Complaint? fromJson(Map<String, dynamic> j) {
    final created = DateTime.tryParse('${j['createdAt']}');
    if (created == null) return null;
    final status = _statusNamed('${j['status']}') ?? ComplaintStatus.open;
    return Complaint(
      id: '${j['id']}',
      ticket: '${j['ticket']}',
      propertyId: '${j['property']}',
      roomNumber: '${j['room']}',
      floor: (j['floor'] as num?)?.toInt() ?? 0,
      residentName: '${j['resident']}',
      residentPhone: '${j['phone']}',
      category: '${j['category']}',
      description: '${j['description']}',
      source: '${j['source']}',
      createdAt: created,
      status: status,
      assignedTo: '${j['assignedTo'] ?? ''}',
      internalNotes: [
        for (final m in (j['internalNotes'] as List<dynamic>? ?? const []))
          if (m is Map) ?StatusChange.fromJson(Map<String, dynamic>.from(m)),
      ],
      resolution: '${j['resolution'] ?? ''}',
      history: [
        for (final m in (j['history'] as List<dynamic>? ?? const []))
          if (m is Map) ?StatusChange.fromJson(Map<String, dynamic>.from(m)),
      ],
      updatedAt: DateTime.tryParse('${j['updatedAt']}'),
    );
  }
}

ComplaintStatus? _statusNamed(String name) {
  for (final s in ComplaintStatus.values) {
    if (s.name == name) return s;
  }
  return null;
}

/// A review, suggestion, maintenance request or feedback on a resolved complaint. Kept as written.
/// The owner cannot edit a resident's entry; the owner can only add a reply, shown beside it.
enum FeedbackKind { review, suggestion, maintenance, complaintFeedback }

String feedbackKindLabel(FeedbackKind k) => switch (k) {
  FeedbackKind.review => 'Review',
  FeedbackKind.suggestion => 'Suggestion',
  FeedbackKind.maintenance => 'Maintenance request',
  FeedbackKind.complaintFeedback => 'Feedback on a resolved complaint',
};

class ResidentFeedback {
  const ResidentFeedback({
    required this.id,
    required this.propertyId,
    required this.kind,
    required this.residentName,
    required this.text,
    required this.createdAt,
    this.rating = 0,
    this.ownerReply = '',
  });

  final String id;
  final String propertyId;
  final FeedbackKind kind;
  final String residentName;
  final String text;

  /// 1 to 5 for a review; 0 when the kind has no rating.
  final int rating;
  final DateTime createdAt;
  final String ownerReply;

  ResidentFeedback withReply(String reply) => ResidentFeedback(
    id: id,
    propertyId: propertyId,
    kind: kind,
    residentName: residentName,
    text: text,
    createdAt: createdAt,
    rating: rating,
    ownerReply: reply,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'property': propertyId,
    'kind': kind.name,
    'resident': residentName,
    'text': text,
    'rating': rating,
    'createdAt': createdAt.toIso8601String(),
    'ownerReply': ownerReply,
  };

  static ResidentFeedback? fromJson(Map<String, dynamic> j) {
    final created = DateTime.tryParse('${j['createdAt']}');
    final kind = FeedbackKind.values
        .where((k) => k.name == '${j['kind']}')
        .firstOrNull;
    if (created == null || kind == null) return null;
    return ResidentFeedback(
      id: '${j['id']}',
      propertyId: '${j['property']}',
      kind: kind,
      residentName: '${j['resident']}',
      text: '${j['text']}',
      rating: (j['rating'] as num?)?.toInt() ?? 0,
      createdAt: created,
      ownerReply: '${j['ownerReply'] ?? ''}',
    );
  }
}

/// A short reference the resident can quote, such as MN-7K3Q. It avoids easily confused characters.
String newTicketRef(math.Random random) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final body = String.fromCharCodes([
    for (var i = 0; i < 4; i++)
      alphabet.codeUnitAt(random.nextInt(alphabet.length)),
  ]);
  return 'MN-$body';
}

/// A complaint already open for the same room and category, raised in the last [window]. Null when none.
/// Used to avoid registering the same problem twice when a resident sends it again.
Complaint? duplicateOf(
  List<Complaint> all, {
  required String propertyId,
  required String roomNumber,
  required String category,
  DateTime? now,
  Duration window = const Duration(days: 2),
}) {
  final today = now ?? DateTime.now();
  for (final c in all) {
    if (c.propertyId != propertyId ||
        c.roomNumber != roomNumber ||
        c.category != category)
      continue;
    if (!c.isOpen) continue;
    if (today.difference(c.createdAt).abs() <= window) return c;
  }
  return null;
}

/// Counts shown on the owner's dashboard.
class ComplaintCounts {
  const ComplaintCounts({
    required this.open,
    required this.acknowledged,
    required this.inProgress,
    required this.resolved,
    required this.closed,
  });

  final int open;
  final int acknowledged;
  final int inProgress;
  final int resolved;
  final int closed;

  /// New means not yet acknowledged.
  int get pending => open + acknowledged + inProgress;

  factory ComplaintCounts.of(Iterable<Complaint> list) {
    var open = 0, ack = 0, prog = 0, res = 0, closed = 0;
    for (final c in list) {
      switch (c.status) {
        case ComplaintStatus.open:
          open++;
        case ComplaintStatus.acknowledged:
          ack++;
        case ComplaintStatus.inProgress:
          prog++;
        case ComplaintStatus.resolved:
          res++;
        case ComplaintStatus.closed:
          closed++;
      }
    }
    return ComplaintCounts(
      open: open,
      acknowledged: ack,
      inProgress: prog,
      resolved: res,
      closed: closed,
    );
  }
}

/// The message a resident can send, with the room filled in. Only the details they give are included.
String complaintMessage({
  required String hostel,
  required String room,
  required String floorText,
  required String category,
  required String description,
  String resident = '',
}) {
  final lines = <String>[
    'Complaint for $hostel',
    if (resident.isNotEmpty) 'Name: $resident',
    'Room: $room',
    'Floor: $floorText',
    'Category: $category',
    'Problem: $description',
  ];
  return lines.join('\n');
}

/// A WhatsApp link that opens a chat with [phone] and fills in [message]. Free: it needs no WhatsApp Business account.
/// Returns null when the number has no digits to dial.
String? whatsappLink(String phone, String message) {
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) digits = '91$digits';
  if (digits.length < 10) return null;
  return 'https://wa.me/$digits?text=${Uri.encodeComponent(message)}';
}

/// The reply the owner sends a resident about a complaint, by WhatsApp.
String complaintUpdateMessage(Complaint c, {required String hostel}) {
  final status = complaintStatusLabel(c.status);
  final note = c.resolution.isNotEmpty ? '\nResolution: ${c.resolution}' : '';
  return 'Update on your complaint ${c.ticket} at $hostel.\nCategory: ${c.category}\nStatus: $status$note\nThank you for your patience.';
}

ComplaintStatus? nextStatus(ComplaintStatus s) => switch (s) {
  ComplaintStatus.open => ComplaintStatus.acknowledged,
  ComplaintStatus.acknowledged => ComplaintStatus.inProgress,
  ComplaintStatus.inProgress => ComplaintStatus.resolved,
  ComplaintStatus.resolved => ComplaintStatus.closed,
  ComplaintStatus.closed => null,
};

/// Checks a review, suggestion or request before it is saved. Null when it is acceptable.
String? feedbackProblem({
  required String text,
  required FeedbackKind kind,
  required int rating,
  required String residentName,
}) {
  if (residentName.trim().isEmpty) return 'Enter the name of the resident.';
  final t = text.trim();
  if (t.length < 5) return 'Write a few words so the owner understands.';
  if (t.length > 1000) return 'Keep it under 1000 characters.';
  if (kind == FeedbackKind.review && (rating < 1 || rating > 5))
    return 'Give a rating from 1 to 5 stars.';
  // Repeated characters or a single word repeated are usually spam or a mistake.
  if (RegExp(r'(.)\1{7,}').hasMatch(t))
    return 'That text looks like a mistake. Please write it again.';
  return null;
}
