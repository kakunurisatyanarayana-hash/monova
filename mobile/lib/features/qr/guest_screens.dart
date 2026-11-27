import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/qr_payloads.dart';
import '../../core/qr_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'qr_common.dart';

String _id() => DateTime.now().microsecondsSinceEpoch.toString();

String _clock(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// The guest list for one invitation: add guests, show each guest's QR code, and see attendance.
class GuestListScreen extends StatefulWidget {
  const GuestListScreen({super.key, required this.eventId});

  final String eventId;

  @override
  State<GuestListScreen> createState() => _GuestListScreenState();
}

class _GuestListScreenState extends State<GuestListScreen> {
  List<GuestRecord> _all = const [];
  String _title = 'Guest list';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final guests = await QrStore.loadGuests();
    final invites = await QrStore.loadInvitations();
    final match = invites.where((i) => i.id == widget.eventId).toList();
    if (mounted) setState(() {
      _all = guests;
      if (match.isNotEmpty) _title = '${match.first.bride} & ${match.first.groom}';
      _loaded = true;
    });
  }

  Future<void> _save(List<GuestRecord> next) async {
    setState(() => _all = next);
    await QrStore.saveGuests(next);
  }

  Future<void> _add() async {
    final g = await FormSheet.show<GuestRecord>(context, title: 'Add a guest', child: _GuestForm(eventId: widget.eventId));
    if (g == null) return;
    await _save([..._all, g]);
  }

  Future<void> _edit(GuestRecord g) async {
    final updated = await FormSheet.show<GuestRecord>(context, title: 'Edit guest', child: _GuestForm(eventId: widget.eventId, initial: g));
    if (updated == null) return;
    await _save([for (final x in _all) x.id == g.id ? updated : x]);
  }

  Future<void> _delete(GuestRecord g) async {
    await _save([for (final x in _all) if (x.id != g.id) x]);
  }

  void _showQr(GuestRecord g) {
    FormSheet.show<void>(
      context,
      title: g.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QrCard(
            payload: g.payload,
            boundaryKey: GlobalKey(),
            title: g.name,
            subtitle: '${g.people} ${g.people == 1 ? 'person' : 'people'} · show this at the entrance',
            size: 200,
          ),
          const SizedBox(height: 10),
          Text('This code only identifies the guest. Anyone who has it can enter, so share it only with that guest.', style: TextStyle(color: context.monova.muted, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final guests = [for (final g in _all) if (g.eventId == widget.eventId) g];
    final s = attendanceFor(_all, widget.eventId);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      floatingActionButton: _loaded
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/qr/scan/${widget.eventId}'),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Entrance check-in'),
            )
          : null,
      body: !_loaded
          ? const LoadingBox()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                MonovaCard(
                  gradient: c.hero,
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 18,
                    runSpacing: 10,
                    children: [
                      _Figure(label: 'Invited', value: '${s.invited} (${s.peopleInvited} people)'),
                      _Figure(label: 'Checked in', value: '${s.checkedIn} (${s.peopleIn} people)'),
                      _Figure(label: 'Coming', value: '${s.yes}'),
                      _Figure(label: 'Not coming', value: '${s.no}'),
                      _Figure(label: 'Not replied', value: '${s.unknown}'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _add,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add a guest'),
                ),
                const SizedBox(height: 12),
                if (guests.isEmpty)
                  EmptyState(icon: Icons.groups_2_outlined, title: 'No guests yet', message: 'Add each guest. Each one gets a code for the entrance.', actionLabel: 'Add the first guest', onAction: _add)
                else
                  for (final g in guests) ...[
                    MonovaCard(
                      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                      onTap: () => _showQr(g),
                      child: Row(
                        children: [
                          Icon(g.checkedIn ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: g.checkedIn ? c.income : c.muted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  '${g.people} ${g.people == 1 ? 'person' : 'people'} · ${_rsvpText(g.rsvp)}'
                                  '${g.checkedIn ? ' · in at ${_clock(g.checkedInAt!)}' : ''}',
                                  style: TextStyle(color: c.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(tooltip: 'Edit', icon: Icon(Icons.edit_outlined, color: c.accentStart), onPressed: () => _edit(g)),
                          IconButton(tooltip: 'Delete', icon: Icon(Icons.delete_outline_rounded, color: c.muted), onPressed: () => _delete(g)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
              ],
            ),
    );
  }

  static String _rsvpText(String rsvp) => switch (rsvp) {
        'yes' => 'Coming',
        'no' => 'Not coming',
        _ => 'Not replied',
      };
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }
}

class _GuestForm extends StatefulWidget {
  const _GuestForm({required this.eventId, this.initial});

  final String eventId;
  final GuestRecord? initial;

  @override
  State<_GuestForm> createState() => _GuestFormState();
}

class _GuestFormState extends State<_GuestForm> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final _people = TextEditingController(text: '${widget.initial?.people ?? 1}');
  late String _rsvp = widget.initial?.rsvp ?? 'unknown';
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _people.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final people = int.tryParse(_people.text.trim()) ?? 0;
    if (name.isEmpty) {
      setState(() => _error = 'Enter the guest\'s name.');
      return;
    }
    if (people < 1 || people > 20) {
      setState(() => _error = 'Enter how many people this invitation admits (1 to 20).');
      return;
    }
    final base = widget.initial;
    Navigator.of(context).pop(GuestRecord(
      id: base?.id ?? _id(),
      eventId: widget.eventId,
      name: name,
      phone: _phone.text.trim(),
      rsvp: _rsvp,
      checkedInAt: base?.checkedInAt,
      people: people,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(controller: _name, autofocus: widget.initial == null, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Guest name *')),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Mobile (optional)')),
        const SizedBox(height: 12),
        TextField(controller: _people, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'People this invitation admits *')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _rsvp,
          decoration: const InputDecoration(labelText: 'Will they come? (RSVP)'),
          items: const [
            DropdownMenuItem(value: 'unknown', child: Text('Not replied yet')),
            DropdownMenuItem(value: 'yes', child: Text('Coming')),
            DropdownMenuItem(value: 'no', child: Text('Not coming')),
          ],
          onChanged: (v) => setState(() => _rsvp = v ?? _rsvp),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _save, child: const Text('Save guest')),
      ],
    );
  }
}

/// Scans a code. With an event, a guest code checks that guest in once; any other code is shown for the user to confirm.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.eventId});

  final String? eventId;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController();
  String? _lastRaw;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _showing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_showing) return;
    final raw = capture.barcodes.isEmpty ? null : capture.barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;
    final now = DateTime.now();
    if (raw == _lastRaw && now.difference(_lastAt).inSeconds < 4) return;
    _lastRaw = raw;
    _lastAt = now;
    _showing = true;
    try {
      final eventId = widget.eventId;
      final guestCode = parseGuestPayload(raw);
      if (eventId != null && guestCode != null && guestCode.eventId == eventId) {
        await _checkIn(eventId, guestCode.guestId, now);
      } else {
        await _showInfo(raw);
      }
    } finally {
      _showing = false;
    }
  }

  Future<void> _checkIn(String eventId, String guestId, DateTime now) async {
    final guests = await QrStore.loadGuests();
    final result = checkInGuest(guests, eventId, guestId, now);
    if (result.outcome == CheckInOutcome.checkedIn) {
      await QrStore.saveGuests(result.guests);
    }
    final name = result.guest?.name ?? 'Unknown guest';
    final (title, message, color) = switch (result.outcome) {
      CheckInOutcome.checkedIn => ('Checked in', '$name is in. Welcome.', context.monova.income),
      CheckInOutcome.alreadyCheckedIn => ('Already checked in', '$name was checked in at ${_clock(result.guest!.checkedInAt!)}. Not recorded again.', context.monova.warning),
      CheckInOutcome.notOnList => ('Not on the list', 'This code is not on this guest list. Check the invitation.', context.monova.expense),
    };
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }

  Future<void> _showInfo(String raw) async {
    final info = classifyScan(raw);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final c = ctx.monova;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(info.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 8),
                Text(info.detail, style: TextStyle(color: c.muted, height: 1.4)),
                const SizedBox(height: 16),
                if (info.openable && info.url != null)
                  FilledButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (d) => AlertDialog(
                          title: const Text('Open this link?'),
                          content: Text(info.url!),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Open')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        final uri = Uri.tryParse(info.url!);
                        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(info.kind == ScanKind.location ? 'Open in a map app' : 'Open link'),
                  ),
                const SizedBox(height: 8),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final checking = widget.eventId != null;
    return Scaffold(
      appBar: AppBar(title: Text(checking ? 'Entrance check-in' : 'Scan a code')),
      body: Column(
        children: [
          Expanded(
            child: ClipRRect(
              child: MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'The camera could not be opened. Allow camera access for MONOVA in phone settings, then try again. '
                      'On the web, allow the camera when the browser asks.\n\n$error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              checking
                  ? 'Point the camera at a guest code. Each guest is checked in once.'
                  : 'Point the camera at a code. Links are shown first, and open only when you confirm.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.monova.muted),
            ),
          ),
        ],
      ),
    );
  }
}
