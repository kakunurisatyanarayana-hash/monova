import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/cloud.dart';
import '../../core/complaints.dart';
import '../../core/format.dart';
import '../../core/hostel_publish.dart';
import '../../core/owner_messages.dart';
import '../../core/property_store.dart';
import '../../core/public_complaints.dart';
import '../../core/rent_status.dart';
import '../../core/theme.dart';
import '../../core/whatsapp_messages.dart';
import '../../core/widgets.dart';

/// Opens WhatsApp with [message] ready for [phone]. The owner still taps Send in WhatsApp.
Future<void> openWhatsAppDraft(
  BuildContext context,
  String phone,
  String message,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final link = whatsappLink(phone, message);
  if (link == null) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Add a valid mobile number first.')),
    );
    return;
  }
  final opened = await launchUrl(
    Uri.parse(link),
    mode: LaunchMode.externalApplication,
  );
  messenger.showSnackBar(
    SnackBar(
      content: Text(
        opened
            ? 'WhatsApp opened. Tap Send in WhatsApp to deliver the message.'
            : 'Could not open WhatsApp on this device.',
      ),
    ),
  );
}

/// The property's address on one line, with a Map button that opens the location in the phone's map app.
class PropertyLocationRow extends StatelessWidget {
  const PropertyLocationRow({super.key, required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final address = [
      property.address,
      property.cityVillage,
      property.mandal,
      property.district,
      property.state,
      property.pinCode,
    ].where((s) => s.isNotEmpty).join(', ');
    final query = '${property.latitude},${property.longitude}';
    return Row(
      children: [
        Icon(Icons.place_outlined, size: 18, color: c.muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
        ),
        TextButton.icon(
          onPressed: () => launchUrl(
            Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'),
            mode: LaunchMode.externalApplication,
          ),
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Map'),
        ),
      ],
    );
  }
}

/// Rent status and WhatsApp messages for one person, shown on the person's page.
class OwnerActions extends StatelessWidget {
  const OwnerActions({super.key, required this.person, required this.book});

  final Person person;
  final PropertyBook book;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    Tenancy? tenancy;
    for (final t in book.tenancies) {
      if (t.personId == person.id && t.isActiveOn(day)) {
        tenancy = t;
        break;
      }
    }
    final property = book.propertyById(
      tenancy?.propertyId ?? person.propertyId,
    );
    final room = tenancy == null ? null : book.roomById(tenancy.roomId);
    final status = tenancy == null ? null : rentStatusFor(book, tenancy, today);
    final hasPhone = person.phone.replaceAll(RegExp(r'\D'), '').length >= 10;
    final overdue = status != null && status.isOverdue(today);

    return MonovaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Rent and messages',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (status == null)
            Text(
              tenancy == null
                  ? 'No active stay, so no rent is due.'
                  : 'No rent set for this stay.',
              style: TextStyle(color: c.muted),
            )
          else ...[
            Text(
              'Monthly rent: ${money(status.amountCents / 100)} · every ${status.tenancy.checkIn.day} of the month',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Paid up to ${dayLabel(status.paidThrough)}',
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: 2),
            Text(
              status.isPaidUpOn(today)
                  ? 'Next due ${dayLabel(status.dueOn)}'
                  : '${money(status.owedCents / 100)} due ${dayLabel(status.dueOn)}${overdue ? ' · overdue' : ''}',
              style: TextStyle(
                color: status.isPaidUpOn(today)
                    ? c.income
                    : (overdue ? c.expense : c.warning),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!hasPhone)
            Text(
              'Add a mobile number to send WhatsApp messages.',
              style: TextStyle(color: c.muted, fontSize: 12),
            )
          else ...[
            if (status != null && !status.isPaidUpOn(today))
              FilledButton.icon(
                onPressed: () => openWhatsAppDraft(
                  context,
                  person.phone,
                  rentDueMessage(
                    hostel: property?.name ?? '',
                    resident: person.name,
                    amount: money(status.owedCents / 100),
                    dueDate: dayLabel(status.dueOn),
                  ),
                ),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send rent reminder on WhatsApp'),
              ),
            if (room != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _sendWelcome(context, property, room),
                icon: const Icon(Icons.link_rounded),
                label: const Text('Send welcome with complaint link'),
              ),
            ],
          ],
          if (room != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _showQr(context, property, room),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('Show complaint QR'),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'WhatsApp opens with the message ready. Monova cannot confirm it was sent; tap Send in WhatsApp.',
            style: TextStyle(color: c.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  /// The complaint link for this room. It carries the hostel code once direct complaints are on.
  Future<String> _complaintLink(Property? property, Room room) async {
    final code = property == null
        ? null
        : await HostelPublish.codeFor(property.id);
    return complaintFormLink(
      CloudConfig.hostingBase,
      code: code ?? '',
      room: room.number,
      floor: room.floor,
      phone: property?.phone ?? '',
      hostelName: property?.name ?? '',
    );
  }

  /// Shows the complaint link as a QR code, so it can be scanned in person without sending anything.
  Future<void> _showQr(
    BuildContext context,
    Property? property,
    Room room,
  ) async {
    final link = await _complaintLink(property, room);
    if (!context.mounted) return;
    await FormSheet.show<void>(
      context,
      title: 'Complaint QR for Room ${room.number}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: link,
            size: 220,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            'Scan to open the complaint form for this room. No message is sent.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.monova.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _sendWelcome(
    BuildContext context,
    Property? property,
    Room room,
  ) async {
    final hostelName = property?.name ?? '';
    final link = await _complaintLink(property, room);
    if (!context.mounted) return;
    await openWhatsAppDraft(
      context,
      person.phone,
      welcomeWithComplaintLink(
        hostel: hostelName,
        resident: person.name,
        room: room.number,
        link: link,
      ),
    );
  }
}

/// Splits one bill among the active tenants of a property, equally, and sends each share on WhatsApp.
Future<void> showBillSplit(
  BuildContext context,
  PropertyBook book,
  Property property,
) {
  return FormSheet.show<void>(
    context,
    title: 'Split a bill',
    child: _BillSplitForm(book: book, property: property),
  );
}

class _BillSplitForm extends StatefulWidget {
  const _BillSplitForm({required this.book, required this.property});

  final PropertyBook book;
  final Property property;

  @override
  State<_BillSplitForm> createState() => _BillSplitFormState();
}

class _BillSplitFormState extends State<_BillSplitForm> {
  final _amount = TextEditingController();
  final _label = TextEditingController();
  late final List<Tenancy> _active;
  final Set<String> _chosen = {};

  /// Null means the whole property; otherwise only the tenants of that room are listed.
  String? _roomId;

  List<Tenancy> get _scope => _roomId == null
      ? _active
      : [
          for (final t in _active)
            if (t.roomId == _roomId) t,
        ];

  void _pickRoom(String? roomId) {
    setState(() {
      _roomId = roomId;
      _chosen
        ..clear()
        ..addAll(_scope.map((t) => t.id));
    });
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _active = [
      for (final t in widget.book.tenancies)
        if (t.propertyId == widget.property.id && t.isActiveOn(today)) t,
    ];
    _chosen.addAll(_active.map((t) => t.id));
  }

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final amount = parseAmount(_amount.text);
    final chosen = [
      for (final t in _active)
        if (_chosen.contains(t.id)) t,
    ];
    final cents = amount == null ? 0 : (amount * 100).round();
    final shares = splitEqually(cents, chosen.length);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Total amount (₹)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _label,
            decoration: const InputDecoration(
              labelText:
                  'What is it for? (for example Maintenance, Electricity)',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Text(
            'Split for',
            style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Whole property'),
                selected: _roomId == null,
                onSelected: (_) => _pickRoom(null),
              ),
              for (final r in widget.book.rooms)
                if (r.propertyId == widget.property.id && !r.archived)
                  ChoiceChip(
                    label: Text('Room ${r.number}'),
                    selected: _roomId == r.id,
                    onSelected: (_) => _pickRoom(r.id),
                  ),
            ],
          ),
          const SizedBox(height: 12),
          if (_scope.isEmpty)
            Text(
              'No active tenants here yet.',
              style: TextStyle(color: c.muted),
            )
          else ...[
            Text(
              'Share with',
              style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
            ),
            for (final t in _scope)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _chosen.contains(t.id),
                title: Text(t.name),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _chosen.add(t.id);
                  } else {
                    _chosen.remove(t.id);
                  }
                }),
              ),
          ],
          if (cents > 0 && chosen.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < chosen.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${chosen[i].name}: ${money(shares[i] / 100)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => openWhatsAppDraft(
                        context,
                        chosen[i].phone,
                        billShareMessage(
                          hostel: widget.property.name,
                          resident: chosen[i].name,
                          label:
                              '${monthLabel(DateTime.now().year, DateTime.now().month)} ${_label.text}',
                          share: money(shares[i] / 100),
                        ),
                      ),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: const Text('WhatsApp'),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            'Shares are equal. Each WhatsApp message opens ready to send; tap Send in WhatsApp.',
            style: TextStyle(color: c.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
