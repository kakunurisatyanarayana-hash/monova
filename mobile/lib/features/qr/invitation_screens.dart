import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:latlong2/latlong.dart';

import '../../core/format.dart';
import '../../core/qr_payloads.dart';
import '../../core/qr_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../shared/date_inputs.dart';
import '../property/map_picker.dart';
import 'qr_common.dart';

/// Colour templates for the invitation card. Each is a background, text colour and accent.
class InviteTemplate {
  const InviteTemplate(this.name, this.background, this.ink, this.accent);

  final String name;
  final Color background;
  final Color ink;
  final Color accent;
}

const inviteTemplates = <InviteTemplate>[
  InviteTemplate('Cream', Color(0xFFFFF8F0), Color(0xFF3B2A1E), Color(0xFF8B5E3C)),
  InviteTemplate('Midnight', Color(0xFF1F2A44), Colors.white, Color(0xFFE7C873)),
  InviteTemplate('Lavender', Color(0xFFF3E9F7), Color(0xFF3A2250), Color(0xFF7B3FA0)),
];

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

/// The wedding invitations on this phone, newest first.
class InvitationListScreen extends StatefulWidget {
  const InvitationListScreen({super.key});

  @override
  State<InvitationListScreen> createState() => _InvitationListScreenState();
}

class _InvitationListScreenState extends State<InvitationListScreen> {
  List<Invitation> _items = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await QrStore.loadInvitations();
    if (mounted) setState(() {
      _items = list;
      _loaded = true;
    });
  }

  Future<void> _new() async {
    final inv = await FormSheet.show<Invitation>(context, title: 'New invitation', child: const InvitationForm());
    if (inv == null) return;
    final next = [inv, ..._items];
    setState(() => _items = next);
    await QrStore.saveInvitations(next);
    if (mounted) context.push('/qr/invites/${inv.id}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(title: const Text('Wedding invitations')),
      floatingActionButton: _loaded
          ? FloatingActionButton.extended(onPressed: _new, icon: const Icon(Icons.add_rounded), label: const Text('New invitation'))
          : null,
      body: !_loaded
          ? const LoadingBox()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                MonovaCard(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Each invitation is one QR code that holds the whole invitation, so it works with no internet. '
                    'Share it as a picture or save it as a PDF.',
                    style: TextStyle(color: c.muted, height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                if (_items.isEmpty)
                  EmptyState(
                    icon: Icons.celebration_outlined,
                    title: 'No invitation yet',
                    message: 'Add the couple, the date, the venue and the schedule. A QR code is made for you.',
                    actionLabel: 'Create the first invitation',
                    onAction: _new,
                  )
                else
                  for (final inv in _items) ...[
                    MonovaCard(
                      padding: const EdgeInsets.all(14),
                      onTap: () => context.push('/qr/invites/${inv.id}'),
                      child: Row(
                        children: [
                          Icon(Icons.favorite_border_rounded, color: c.accentStart),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${inv.bride} & ${inv.groom}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('${dayLabel(inv.date)} · ${inv.venue}', style: TextStyle(color: c.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: c.muted),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
    );
  }
}

/// One invitation: a styled card with its QR code, template choice, sharing and PDF, and the guest list.
class InvitationDetailScreen extends StatefulWidget {
  const InvitationDetailScreen({super.key, required this.id});

  final String id;

  @override
  State<InvitationDetailScreen> createState() => _InvitationDetailScreenState();
}

class _InvitationDetailScreenState extends State<InvitationDetailScreen> {
  Invitation? _inv;
  bool _loaded = false;
  final _cardKey = GlobalKey();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await QrStore.loadInvitations();
    final matches = all.where((i) => i.id == widget.id).toList();
    if (mounted) setState(() {
      _inv = matches.isEmpty ? null : matches.first;
      _loaded = true;
    });
  }

  Future<void> _save(Invitation next) async {
    setState(() => _inv = next);
    final all = await QrStore.loadInvitations();
    await QrStore.saveInvitations([for (final i in all) i.id == next.id ? next : i]);
  }

  Future<void> _edit() async {
    final inv = _inv;
    if (inv == null) return;
    final updated = await FormSheet.show<Invitation>(context, title: 'Edit invitation', child: InvitationForm(initial: inv));
    if (updated == null) return;
    await _save(updated);
  }

  Future<void> _delete() async {
    final inv = _inv;
    if (inv == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this invitation?'),
        content: const Text('The invitation and its guest list will be removed from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: context.monova.expense),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final all = await QrStore.loadInvitations();
    await QrStore.saveInvitations([for (final i in all) if (i.id != inv.id) i]);
    final guests = await QrStore.loadGuests();
    await QrStore.saveGuests([for (final g in guests) if (g.eventId != inv.id) g]);
    if (mounted) context.pop();
  }

  Future<void> _sharePicture(Invitation inv) async {
    setState(() => _busy = true);
    try {
      final png = await captureQrPng(_cardKey);
      if (png == null) return;
      await shareQrPng(png, fileName: 'invitation-${inv.id}.png', text: 'Wedding invitation: ${inv.bride} & ${inv.groom}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePdf(Invitation inv) async {
    final bytes = await invitationPdf(inv);
    await Printing.sharePdf(bytes: bytes, filename: 'invitation-${inv.bride}-${inv.groom}.pdf'.replaceAll(' ', '_'));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final inv = _inv;
    if (!_loaded) return const Scaffold(body: LoadingBox());
    if (inv == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Invitation')),
        body: const EmptyState(icon: Icons.error_outline_rounded, title: 'Invitation not found', message: 'It may have been deleted.'),
      );
    }
    final template = inviteTemplates[inv.template.clamp(0, inviteTemplates.length - 1)];
    final problem = payloadProblem(invitationPayload(inv));
    return Scaffold(
      appBar: AppBar(
        title: Text('${inv.bride} & ${inv.groom}'),
        actions: [
          IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
          IconButton(tooltip: 'Delete', icon: Icon(Icons.delete_outline_rounded, color: c.expense), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < inviteTemplates.length; i++)
                ChoiceChip(
                  label: Text(inviteTemplates[i].name),
                  selected: inv.template == i,
                  onSelected: (_) => _save(inv.copyWith(template: i)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (problem != null)
            MonovaCard(
              padding: const EdgeInsets.all(14),
              child: Text(problem, style: TextStyle(color: c.expense, height: 1.4)),
            )
          else
            _InviteCard(invitation: inv, template: template, cardKey: _cardKey),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: problem != null || _busy ? null : () => _sharePicture(inv),
            icon: const Icon(Icons.share_rounded),
            label: Text(_busy ? 'Making the picture…' : 'Share as picture (WhatsApp and more)'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: problem != null ? null : () => _savePdf(inv),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: const Text('Save or print as PDF'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => context.push('/qr/guests/${inv.id}'),
            icon: const Icon(Icons.groups_2_outlined),
            label: const Text('Guest list and entrance check-in'),
          ),
          const SizedBox(height: 12),
          Text(
            'The QR code holds the full invitation, so a scan shows it even without internet. '
            'Keep the picture or PDF to share; keep the schedule short so the code stays easy to scan.',
            style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.invitation, required this.template, required this.cardKey});

  final Invitation invitation;
  final InviteTemplate template;
  final GlobalKey cardKey;

  @override
  Widget build(BuildContext context) {
    final inv = invitation;
    final ink = template.ink;
    return RepaintBoundary(
      key: cardKey,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: template.background, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Text('Together with their families', textAlign: TextAlign.center, style: TextStyle(color: ink.withValues(alpha: 0.8), fontSize: 12)),
            const SizedBox(height: 8),
            Text(inv.bride, textAlign: TextAlign.center, style: TextStyle(color: ink, fontSize: 26, fontWeight: FontWeight.w800)),
            Text('&', style: TextStyle(color: template.accent, fontSize: 20, fontWeight: FontWeight.w700)),
            Text(inv.groom, textAlign: TextAlign.center, style: TextStyle(color: ink, fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Text(dayLabel(inv.date), style: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w700)),
            if (inv.timings.isNotEmpty) Text(inv.timings, style: TextStyle(color: ink.withValues(alpha: 0.85))),
            const SizedBox(height: 6),
            Text(inv.venue, textAlign: TextAlign.center, style: TextStyle(color: ink, fontWeight: FontWeight.w600)),
            if (inv.address.isNotEmpty) Text(inv.address, textAlign: TextAlign.center, style: TextStyle(color: ink.withValues(alpha: 0.85), fontSize: 12)),
            if (inv.schedule.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final line in inv.schedule)
                Text(line, textAlign: TextAlign.center, style: TextStyle(color: ink.withValues(alpha: 0.9), fontSize: 13)),
            ],
            if (inv.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(inv.message, textAlign: TextAlign.center, style: TextStyle(color: ink, fontStyle: FontStyle.italic, height: 1.4)),
            ],
            const SizedBox(height: 16),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(10),
              child: QrImageView(data: invitationPayload(inv), size: 200, errorCorrectionLevel: QrErrorCorrectLevel.M, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 6),
            Text('Scan to see the invitation', style: TextStyle(color: ink.withValues(alpha: 0.7), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// The PDF version of an invitation, with a vector QR code.
Future<Uint8List> invitationPdf(Invitation inv) async {
  final doc = pw.Document();
  final payload = invitationPayload(inv);
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(48),
    build: (context) => pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text('${inv.bride} & ${inv.groom}', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text('${dayLabel(inv.date)}${inv.timings.isEmpty ? '' : '  ·  ${inv.timings}'}', style: const pw.TextStyle(fontSize: 14)),
        pw.SizedBox(height: 6),
        pw.Text(inv.venue, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        if (inv.address.isNotEmpty) pw.Text(inv.address, style: const pw.TextStyle(fontSize: 12)),
        if (inv.schedule.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          for (final line in inv.schedule) pw.Text(line, style: const pw.TextStyle(fontSize: 12)),
        ],
        if (inv.message.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Text(inv.message, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 12)),
        ],
        pw.SizedBox(height: 24),
        pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: payload, width: 180, height: 180),
        pw.SizedBox(height: 6),
        pw.Text('Scan the code to see the invitation', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      ],
    ),
  ));
  return doc.save();
}

/// Creates or edits an invitation.
class InvitationForm extends StatefulWidget {
  const InvitationForm({super.key, this.initial});

  final Invitation? initial;

  @override
  State<InvitationForm> createState() => _InvitationFormState();
}

class _InvitationFormState extends State<InvitationForm> {
  late final _bride = TextEditingController(text: widget.initial?.bride ?? '');
  late final _groom = TextEditingController(text: widget.initial?.groom ?? '');
  late final _venue = TextEditingController(text: widget.initial?.venue ?? '');
  late final _address = TextEditingController(text: widget.initial?.address ?? '');
  late final _timings = TextEditingController(text: widget.initial?.timings ?? '');
  late final _schedule = TextEditingController(text: (widget.initial?.schedule ?? const []).join('\n'));
  late final _message = TextEditingController(text: widget.initial?.message ?? '');
  late DateTime _date = widget.initial?.date ?? DateTime.now().add(const Duration(days: 30));
  late LatLng? _point = widget.initial?.latitude == null || widget.initial?.longitude == null
      ? null
      : LatLng(widget.initial!.latitude!, widget.initial!.longitude!);
  String? _error;

  @override
  void dispose() {
    for (final c in [_bride, _groom, _venue, _address, _timings, _schedule, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPoint() async {
    final pick = await Navigator.of(context).push<MapPick>(MaterialPageRoute(builder: (_) => MapPickerScreen(initial: _point)));
    if (pick == null || !mounted) return;
    setState(() => _point = pick.point);
  }

  void _save() {
    final bride = _bride.text.trim();
    final groom = _groom.text.trim();
    final venue = _venue.text.trim();
    final schedule = [for (final l in _schedule.text.split('\n')) if (l.trim().isNotEmpty) l.trim()];
    String? problem;
    if (bride.isEmpty || groom.isEmpty) {
      problem = 'Enter both names.';
    } else if (venue.isEmpty) {
      problem = 'Enter the venue.';
    } else if (schedule.length > 12) {
      problem = 'Keep the schedule to 12 lines or fewer.';
    }
    final draft = Invitation(
      id: widget.initial?.id ?? _id(),
      bride: bride,
      groom: groom,
      date: DateTime(_date.year, _date.month, _date.day),
      venue: venue,
      address: _address.text.trim(),
      timings: _timings.text.trim(),
      schedule: schedule,
      message: _message.text.trim(),
      latitude: _point?.latitude,
      longitude: _point?.longitude,
      template: widget.initial?.template ?? 0,
    );
    problem ??= payloadProblem(invitationPayload(draft));
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _bride, autofocus: widget.initial == null, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Bride name *')),
        const SizedBox(height: 12),
        TextField(controller: _groom, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Groom name *')),
        const SizedBox(height: 12),
        DateSelector(label: 'Wedding date', value: _date, firstYear: DateTime.now().year, lastYear: DateTime.now().year + 5, onChanged: (d) => setState(() => _date = d)),
        const SizedBox(height: 12),
        TextField(controller: _timings, decoration: const InputDecoration(labelText: 'Timings (for example 10:00 AM onwards)')),
        const SizedBox(height: 12),
        TextField(controller: _venue, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Venue *')),
        const SizedBox(height: 12),
        TextField(controller: _address, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Address and directions (optional)')),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _pickPoint,
          icon: const Icon(Icons.map_rounded, size: 18),
          label: Text(_point == null ? 'Pin the venue on the map (optional)' : 'Venue pinned on the map'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _schedule,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(labelText: 'Schedule, one event per line', hintText: '10:00 Muhurtham\n19:30 Dinner', alignLabelWithHint: true),
        ),
        const SizedBox(height: 12),
        TextField(controller: _message, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Invitation message (optional)', alignLabelWithHint: true)),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: Text(widget.initial == null ? 'Create invitation' : 'Save changes')),
      ],
    );
  }
}
