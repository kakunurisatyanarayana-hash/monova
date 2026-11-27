// Prefilled WhatsApp messages. Monova only opens WhatsApp with the text filled in; the person must press Send.
// Nothing here sends a message by itself, and the app must never say a message was sent just because WhatsApp opened.
// Pure Dart.

/// The seven message types the approval allows.
enum WhatsAppTemplate { welcome, complaintReceived, complaintUpdate, complaintResolved, rentDue, paymentDue, announcement }

String whatsAppTemplateLabel(WhatsAppTemplate t) => switch (t) {
      WhatsAppTemplate.welcome => 'Welcome a new resident',
      WhatsAppTemplate.complaintReceived => 'Complaint received',
      WhatsAppTemplate.complaintUpdate => 'Complaint status update',
      WhatsAppTemplate.complaintResolved => 'Complaint resolved',
      WhatsAppTemplate.rentDue => 'Rent due reminder',
      WhatsAppTemplate.paymentDue => 'Payment reminder',
      WhatsAppTemplate.announcement => 'Hostel announcement',
    };

String welcomeMessage({required String hostel, required String resident, required String room}) =>
    'Hello $resident, welcome to $hostel. Your room is $room. Please reply here if you need anything.';

String complaintReceivedMessage({required String hostel, required String ticket, required String room, required String category}) =>
    'Thank you. We have received your complaint at $hostel.\nReference: $ticket\nRoom: $room\nCategory: $category\nWe will update you here.';

String complaintUpdateMessage({required String hostel, required String ticket, required String status}) =>
    'Update on your complaint $ticket at $hostel.\nStatus: $status';

String complaintResolvedMessage({required String hostel, required String ticket, required String resolution}) {
  final note = resolution.trim().isEmpty ? '' : '\nWhat was done: ${resolution.trim()}';
  return 'Your complaint $ticket at $hostel is resolved.$note\nThank you for your patience.';
}

String rentDueMessage({required String hostel, required String resident, required String amount, required String dueDate}) =>
    'Hello $resident, this is a reminder that rent of $amount for $hostel is due on $dueDate. Thank you.';

String paymentDueMessage({required String hostel, required String resident, required String amount, required String dueDate}) =>
    'Hello $resident, a payment of $amount for $hostel is due on $dueDate. Please let us know once it is paid.';

String announcementMessage({required String hostel, required String text}) => '$hostel announcement:\n${text.trim()}';

/// The message for a template. Missing details are left out rather than filled with guesses.
String whatsAppMessage(WhatsAppTemplate t, Map<String, String> details) {
  String v(String k) => (details[k] ?? '').trim();
  return switch (t) {
    WhatsAppTemplate.welcome => welcomeMessage(hostel: v('hostel'), resident: v('resident'), room: v('room')),
    WhatsAppTemplate.complaintReceived => complaintReceivedMessage(hostel: v('hostel'), ticket: v('ticket'), room: v('room'), category: v('category')),
    WhatsAppTemplate.complaintUpdate => complaintUpdateMessage(hostel: v('hostel'), ticket: v('ticket'), status: v('status')),
    WhatsAppTemplate.complaintResolved => complaintResolvedMessage(hostel: v('hostel'), ticket: v('ticket'), resolution: v('resolution')),
    WhatsAppTemplate.rentDue => rentDueMessage(hostel: v('hostel'), resident: v('resident'), amount: v('amount'), dueDate: v('due')),
    WhatsAppTemplate.paymentDue => paymentDueMessage(hostel: v('hostel'), resident: v('resident'), amount: v('amount'), dueDate: v('due')),
    WhatsAppTemplate.announcement => announcementMessage(hostel: v('hostel'), text: v('text')),
  };
}
