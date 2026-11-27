import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/complaint_store.dart';
import '../../core/cloud_sync.dart';
import '../../core/complaints.dart';
import '../../core/notification_store.dart';
import '../../core/notifications.dart';
import '../../core/format.dart';
import '../../core/i18n_hostel.dart';
import '../../core/input_rules.dart';
import '../../core/property_store.dart';
import '../../core/share_text.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// The hostel hub: the owner's summary of beds, complaints and feedback, with the things to do next.
class HostelHubScreen extends StatefulWidget {
  const HostelHubScreen({super.key, required this.id});

  final String id;

  @override
  State<HostelHubScreen> createState() => _HostelHubScreenState();
}

class _HostelHubScreenState extends State<HostelHubScreen> {
  PropertyBook? _book;
  List<Complaint> _complaints = const [];
  List<ResidentFeedback> _feedback = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final book = await PropertyStore.load();
      final complaints = await ComplaintStore.loadComplaints();
      final feedback = await ComplaintStore.loadFeedback();
      if (!mounted) return;
      setState(() {
        _book = book;
        _complaints = complaints;
        _feedback = feedback;
      });
    } catch (e) {
      debugPrint('Hostel hub load failed: $e');
      if (mounted) setState(() => _error = e);
    }
  }

  /// Lists the rooms, sorted by floor, and opens the QR code for the one chosen.
  Future<void> _pickRoomQr(Property property, List<Room> rooms) async {
    final sorted = [...rooms]..sort((a, b) => a.floor != b.floor ? a.floor.compareTo(b.floor) : a.number.compareTo(b.number));
    if (sorted.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a room first.')));
      return;
    }
    await FormSheet.show<void>(
      context,
      title: 'Room QR codes',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final r in sorted)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.qr_code_2_rounded),
              title: Text('Room ${r.number}'),
              subtitle: Text(floorLabel(r.floor)),
              onTap: () => FormSheet.show<void>(
                context,
                title: 'Room ${r.number} code',
                child: RoomQrSheet(property: property, room: r),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final book = _book;
    if (_error != null) {
      return const Scaffold(body: EmptyState(icon: Icons.error_outline_rounded, title: 'Could not open the hostel', message: 'Nothing was changed. Try again.'));
    }
    if (book == null) return const Scaffold(body: LoadingBox());
    final property = book.propertyById(widget.id);
    if (property == null) {
      return const Scaffold(body: EmptyState(icon: Icons.search_off_rounded, title: 'Property not found', message: 'It may have been deleted.'));
    }
    final rooms = book.roomsOf(property.id);
    final summary = summarizeProperty(property.id, book, DateTime.now());
    final totalBeds = rooms.fold<int>(0, (t, r) => t + r.beds);
    final occupied = summary.rooms.fold<int>(0, (t, s) => t + s.occupiedBeds);
    final vacant = (totalBeds - occupied).clamp(0, totalBeds);
    final occupancy = totalBeds == 0 ? 0 : (occupied * 100 / totalBeds).round();
    final mine = [for (final x in _complaints) if (x.propertyId == property.id) x];
    final counts = ComplaintCounts.of(mine);
    final myFeedback = [for (final f in _feedback) if (f.propertyId == property.id) f]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final maintenance = rooms.where((r) => r.maintenance).length;

    return Scaffold(
      appBar: AppBar(title: Text(property.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('Floors, rooms, beds and complaints for this hostel.', style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 12),
          EqualTileGrid(
            minTileWidth: 150,
            tileHeight: 92,
            children: [
              _Stat(label: ht('Floors'), value: '${property.floors}', c: c),
              _Stat(label: ht('Rooms'), value: '${rooms.length}', c: c),
              _Stat(label: ht('Total beds'), value: '$totalBeds', c: c),
              _Stat(label: ht('Occupied beds'), value: '$occupied', c: c),
              _Stat(label: ht('Vacant beds'), value: '$vacant', c: c),
              _Stat(label: ht('Occupancy'), value: '$occupancy%', c: c),
              _Stat(label: ht('Pending complaints'), value: '${counts.pending}', c: c, alert: counts.pending > 0),
              _Stat(label: ht('Maintenance rooms'), value: '$maintenance', c: c),
            ],
          ),
          const SizedBox(height: 16),
          SectionTitle(ht('Do next')),
          const SizedBox(height: 8),
          EqualTileGrid(
            minTileWidth: 150,
            tileHeight: 64,
            children: [
              _Action(icon: Icons.apartment_rounded, label: ht('Floors and rooms'), onTap: () => context.push('/property/${property.id}')),
              _Action(icon: Icons.person_add_alt_rounded, label: ht('Add resident'), onTap: () => context.push('/property/${property.id}')),
              _Action(icon: Icons.event_available_rounded, label: ht('View vacancies'), onTap: () => context.push('/property/${property.id}')),
              _Action(icon: Icons.report_problem_outlined, label: ht('Complaints'), onTap: () => context.push('/property/${property.id}/complaints')),
              _Action(icon: Icons.rate_review_outlined, label: ht('Reviews and suggestions'), onTap: () => context.push('/property/${property.id}/feedback')),
              _Action(icon: Icons.qr_code_2_rounded, label: ht('Room QR codes'), onTap: () => _pickRoomQr(property, rooms)),
            ],
          ),
          const SizedBox(height: 16),
          SectionTitle(ht('Complaints')),
          const SizedBox(height: 8),
          MonovaCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CountRow(label: ht('New (open)'), value: counts.open, c: c),
                _CountRow(label: ht('Acknowledged'), value: counts.acknowledged, c: c),
                _CountRow(label: ht('In progress'), value: counts.inProgress, c: c),
                _CountRow(label: ht('Resolved'), value: counts.resolved, c: c),
                _CountRow(label: ht('Closed'), value: counts.closed, c: c),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionTitle(ht('Recent reviews and suggestions')),
          const SizedBox(height: 8),
          if (myFeedback.isEmpty)
            MonovaCard(
              padding: const EdgeInsets.all(14),
              child: Text('None yet. Record a review or suggestion when a resident gives one.', style: TextStyle(color: c.muted, height: 1.4)),
            )
          else
            for (final f in myFeedback.take(5)) _FeedbackTile(item: f),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.c, this.alert = false});

  final String label;
  final String value;
  final MonovaColors c;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    return MonovaCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(color: alert ? c.expense : c.ink, fontSize: 22, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: c.muted, fontSize: 12, height: 1.25)),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return MonovaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: c.accentStart, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.label, required this.value, required this.c});

  final String label;
  final int value;
  final MonovaColors c;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: c.ink))),
          Text('$value', style: TextStyle(color: c.ink, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _FeedbackTile extends StatelessWidget {
  const _FeedbackTile({required this.item});

  final ResidentFeedback item;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MonovaCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${feedbackKindLabel(item.kind)} · ${item.residentName} · ${dayLabel(item.createdAt)}', style: TextStyle(color: c.muted, fontSize: 12)),
            if (item.rating > 0) Text('${'★' * item.rating}${'☆' * (5 - item.rating)}', style: TextStyle(color: c.accentStart)),
            const SizedBox(height: 4),
            Text(item.text, style: TextStyle(color: c.ink, height: 1.4)),
            if (item.ownerReply.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('Owner reply: ${item.ownerReply}', style: TextStyle(color: c.muted, fontSize: 12, height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Complaints

/// Owner's complaint list: filter by status, category and floor, register new ones, and update each one.
class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key, required this.id});

  final String id;

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  PropertyBook? _book;
  List<Complaint> _all = const [];
  ComplaintStatus? _status;
  String? _category;
  int? _floor;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final book = await PropertyStore.load();
    final all = await ComplaintStore.loadComplaints();
    if (!mounted) return;
    setState(() {
      _book = book;
      _all = all;
      _loaded = true;
    });
  }

  Future<void> _save(List<Complaint> next) async {
    await ComplaintStore.saveComplaints(next);
    if (!mounted) return;
    setState(() => _all = next);
  }

  Future<void> _register(Property property) async {
    final book = _book;
    if (book == null) return;
    await FormSheet.show<void>(
      context,
      title: 'Register a complaint',
      child: _NewComplaintForm(
        property: property,
        rooms: book.roomsOf(property.id),
        existing: _all,
        onSave: (c) async {
          await _save([c, ..._all]);
        },
      ),
    );
  }

  Future<void> _open(Property property, Complaint c) async {
    await FormSheet.show<void>(
      context,
      title: 'Complaint ${c.ticket}',
      child: _ComplaintDetail(
        complaint: c,
        hostel: property.name,
        hostelPhone: property.phone,
        onChanged: (updated) async {
          await _save([for (final x in _all) x.id == updated.id ? updated : x]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final book = _book;
    if (!_loaded || book == null) return const Scaffold(body: LoadingBox());
    final property = book.propertyById(widget.id);
    if (property == null) {
      return const Scaffold(body: EmptyState(icon: Icons.search_off_rounded, title: 'Property not found', message: 'It may have been deleted.'));
    }
    final mine = [for (final x in _all) if (x.propertyId == property.id) x]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final shown = mine.where((x) {
      if (_status != null && x.status != _status) return false;
      if (_category != null && x.category != _category) return false;
      if (_floor != null && x.floor != _floor) return false;
      return true;
    }).toList();
    final counts = ComplaintCounts.of(mine);
    final floors = {for (final x in mine) x.floor}.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Complaints')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _register(property),
        icon: const Icon(Icons.add_rounded),
        label: Text(ht('Register')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          Text(
            '${counts.pending} pending · ${counts.resolved} resolved · ${mine.length} in total',
            style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: const Text('All status'), selected: _status == null, onSelected: (_) => setState(() => _status = null)),
              for (final s in ComplaintStatus.values)
                ChoiceChip(label: Text(complaintStatusLabel(s)), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  key: ValueKey('cat-$_category'),
                  initialValue: _category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('All categories')),
                    for (final cat in complaintCategories) DropdownMenuItem<String?>(value: cat, child: Text(cat)),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int?>(
                  key: ValueKey('floor-$_floor'),
                  initialValue: _floor,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Floor'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('All floors')),
                    for (final f in floors) DropdownMenuItem<int?>(value: f, child: Text(floorLabel(f))),
                  ],
                  onChanged: (v) => setState(() => _floor = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (shown.isEmpty)
            MonovaCard(
              padding: const EdgeInsets.all(16),
              child: Text(
                mine.isEmpty
                    ? 'No complaints yet. Residents can send one by WhatsApp or the room QR code. Register it here when it arrives.'
                    : 'No complaint matches these filters.',
                style: TextStyle(color: c.muted, height: 1.4),
              ),
            )
          else
            for (final x in shown) _ComplaintRow(complaint: x, onTap: () => _open(property, x)),
        ],
      ),
    );
  }
}

class _ComplaintRow extends StatelessWidget {
  const _ComplaintRow({required this.complaint, required this.onTap});

  final Complaint complaint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final x = complaint;
    final color = x.isOpen ? c.expense : c.income;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MonovaCard(
        onTap: onTap,
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${ht(x.category)} · ${ht('Room')} ${x.roomNumber}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${floorLabel(x.floor)} · ${x.residentName} · ${dayLabel(x.createdAt)}', style: TextStyle(color: c.muted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(x.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.ink, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Text(x.ticket, style: TextStyle(color: c.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
                  child: Text(ht(complaintStatusLabel(x.status)), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Registers a complaint that arrived by WhatsApp, a call, or in person. Warns when the same problem is already open.
class _NewComplaintForm extends StatefulWidget {
  const _NewComplaintForm({required this.property, required this.rooms, required this.existing, required this.onSave});

  final Property property;
  final List<Room> rooms;
  final List<Complaint> existing;
  final Future<void> Function(Complaint) onSave;

  @override
  State<_NewComplaintForm> createState() => _NewComplaintFormState();
}

class _NewComplaintFormState extends State<_NewComplaintForm> {
  Room? _room;
  String _category = complaintCategories.first;
  String _source = complaintSources.first;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _description = TextEditingController();
  String? _error;
  bool _confirmDuplicate = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _description.dispose();
    super.dispose();
  }

  Complaint? get _duplicate => _room == null
      ? null
      : duplicateOf(widget.existing, propertyId: widget.property.id, roomNumber: _room!.number, category: _category);

  Future<void> _submit() async {
    final room = _room;
    final problem = room == null
        ? 'Choose the room.'
        : _name.text.trim().isEmpty
            ? 'Enter the resident\'s name.'
            : _description.text.trim().length < 5
                ? 'Describe the problem in a few words.'
                : null;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final dup = _duplicate;
    if (dup != null && !_confirmDuplicate) {
      setState(() {
        _error = 'This problem is already open as ${dup.ticket}. Press Register again to log it anyway.';
        _confirmDuplicate = true;
      });
      return;
    }
    final random = math.Random();
    final now = DateTime.now();
    final complaint = Complaint(
      id: now.microsecondsSinceEpoch.toString(),
      ticket: newTicketRef(random),
      propertyId: widget.property.id,
      roomNumber: room!.number,
      floor: room.floor,
      residentName: _name.text.trim(),
      residentPhone: _phone.text.trim(),
      category: _category,
      description: _description.text.trim(),
      source: _source,
      createdAt: now,
    );
    await widget.onSave(complaint);
    await queueComplaintForSync(complaint, (_) {});
    await NotificationStore.add(AppNotification(
      id: 'complaint|${complaint.id}|open',
      kind: NotificationKind.complaint,
      title: 'New complaint ${complaint.ticket}',
      body: 'Room ${complaint.roomNumber} · ${complaint.category}. Open it to acknowledge.',
      createdAt: now,
      route: '/property/${complaint.propertyId}/complaints',
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final rooms = [...widget.rooms]..sort((a, b) => a.floor != b.floor ? a.floor.compareTo(b.floor) : a.number.compareTo(b.number));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<Room>(
          key: ValueKey('room-${_room?.id}'),
          initialValue: _room,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Room *'),
          items: [
            for (final r in rooms) DropdownMenuItem(value: r, child: Text('${floorLabel(r.floor)} · Room ${r.number}')),
          ],
          onChanged: (v) => setState(() {
            _room = v;
            _confirmDuplicate = false;
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Resident name *')),
        const SizedBox(height: 12),
        TextField(controller: _phone, keyboardType: TextInputType.phone, inputFormatters: phoneFormatters, decoration: const InputDecoration(labelText: 'Contact number (optional)')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _category,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [for (final cat in complaintCategories) DropdownMenuItem(value: cat, child: Text(cat))],
          onChanged: (v) => setState(() {
            _category = v ?? _category;
            _confirmDuplicate = false;
          }),
        ),
        const SizedBox(height: 12),
        TextField(controller: _description, maxLines: 3, decoration: const InputDecoration(labelText: 'Problem *', hintText: 'Bathroom water leakage')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _source,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'How it arrived'),
          items: [for (final s in complaintSources) DropdownMenuItem(value: s, child: Text(s))],
          onChanged: (v) => setState(() => _source = v ?? _source),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense, height: 1.4)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _submit, child: Text(_confirmDuplicate ? 'Register anyway' : 'Register complaint')),
      ],
    );
  }
}

/// One complaint: its status, who it is assigned to, internal notes, resolution, history, and a WhatsApp reply.
class _ComplaintDetail extends StatefulWidget {
  const _ComplaintDetail({required this.complaint, required this.hostel, required this.hostelPhone, required this.onChanged});

  final Complaint complaint;
  final String hostel;
  final String hostelPhone;
  final Future<void> Function(Complaint) onChanged;

  @override
  State<_ComplaintDetail> createState() => _ComplaintDetailState();
}

class _ComplaintDetailState extends State<_ComplaintDetail> {
  late Complaint _c = widget.complaint;
  final _assign = TextEditingController();
  final _note = TextEditingController();
  final _resolution = TextEditingController();

  @override
  void initState() {
    super.initState();
    _assign.text = _c.assignedTo;
    _resolution.text = _c.resolution;
  }

  @override
  void dispose() {
    _assign.dispose();
    _note.dispose();
    _resolution.dispose();
    super.dispose();
  }

  Future<void> _store(Complaint next) async {
    final statusChanged = next.status != _c.status;
    setState(() => _c = next);
    await widget.onChanged(next);
    if (statusChanged) {
      await queueComplaintForSync(next, (_) {});
      await NotificationStore.add(AppNotification(
        id: 'complaint|${next.id}|${next.status.name}',
        kind: NotificationKind.complaint,
        title: 'Complaint ${next.ticket}: ${complaintStatusLabel(next.status)}',
        body: 'Room ${next.roomNumber} · ${next.category}',
        createdAt: DateTime.now(),
        route: '/property/${next.propertyId}/complaints',
      ));
    }
  }

  Future<void> _advance() async {
    final to = nextStatus(_c.status);
    if (to == null) return;
    final now = DateTime.now();
    await _store(_c.copyWith(
      status: to,
      updatedAt: now,
      history: [..._c.history, StatusChange(at: now, from: _c.status, to: to, note: '')],
    ));
  }

  Future<void> _addNote() async {
    final t = _note.text.trim();
    if (t.isEmpty) return;
    final now = DateTime.now();
    _note.clear();
    await _store(_c.copyWith(internalNotes: [..._c.internalNotes, StatusChange(at: now, from: null, to: _c.status, note: t)], updatedAt: now));
  }

  Future<void> _saveAssignment() async {
    await _store(_c.copyWith(assignedTo: _assign.text.trim(), updatedAt: DateTime.now()));
  }

  Future<void> _saveResolution() async {
    final now = DateTime.now();
    await _store(_c.copyWith(resolution: _resolution.text.trim(), updatedAt: now));
  }

  Future<void> _sendUpdate() async {
    final link = whatsappLink(_c.residentPhone, complaintUpdateMessage(_c, hostel: widget.hostel));
    if (link == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This complaint has no contact number. Add one, or reply in person.')));
      }
      return;
    }
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final next = nextStatus(_c.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${_c.category} · ${floorLabel(_c.floor)} · Room ${_c.roomNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 4),
        Text('${_c.residentName}${_c.residentPhone.isEmpty ? '' : ' · ${_c.residentPhone}'}', style: TextStyle(color: c.muted)),
        const SizedBox(height: 6),
        Text(_c.description, style: TextStyle(color: c.ink, height: 1.4)),
        const SizedBox(height: 6),
        Text('Ref ${_c.ticket} · ${_c.source} · ${dayLabel(_c.createdAt)}', style: TextStyle(color: c.muted, fontSize: 12)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: Text('Status: ${complaintStatusLabel(_c.status)}', style: const TextStyle(fontWeight: FontWeight.w700))),
            if (next != null) FilledButton(onPressed: _advance, child: Text('Mark ${complaintStatusLabel(next).toLowerCase()}')),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(controller: _assign, decoration: const InputDecoration(labelText: 'Assigned to', hintText: 'Plumber or staff name')),
            ),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: _saveAssignment, child: const Text('Save')),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: TextField(controller: _note, decoration: const InputDecoration(labelText: 'Internal note', helperText: 'Only the owner and staff see this'))),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: _addNote, child: const Text('Add')),
          ],
        ),
        for (final n in _c.internalNotes)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${dayLabel(n.at)}: ${n.note}', style: TextStyle(color: c.muted, fontSize: 12)),
          ),
        const SizedBox(height: 14),
        TextField(controller: _resolution, maxLines: 2, decoration: const InputDecoration(labelText: 'Resolution comments', helperText: 'What was done, shown to the resident')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _saveResolution, child: const Text('Save resolution')),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _sendUpdate,
          icon: const Icon(Icons.chat_rounded, size: 18),
          label: const Text('Open WhatsApp with this update'),
        ),
        const SizedBox(height: 14),
        Text('History', style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        if (_c.history.isEmpty)
          Text('Registered as ${complaintStatusLabel(ComplaintStatus.open)}. No status changes yet.', style: TextStyle(color: c.muted, fontSize: 12))
        else
          for (final h in _c.history)
            Text('${dayLabel(h.at)}: ${h.from == null ? '' : '${complaintStatusLabel(h.from!)} → '}${complaintStatusLabel(h.to)}', style: TextStyle(color: c.muted, fontSize: 12)),
      ],
    );
  }
}

// ---------------------------------------------------------------- Feedback

/// Reviews, suggestions and maintenance requests. Entries are kept as written; the owner can only add a reply.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key, required this.id});

  final String id;

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  PropertyBook? _book;
  List<ResidentFeedback> _all = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final book = await PropertyStore.load();
    final all = await ComplaintStore.loadFeedback();
    if (!mounted) return;
    setState(() {
      _book = book;
      _all = all;
      _loaded = true;
    });
  }

  Future<void> _record(Property property) async {
    await FormSheet.show<void>(
      context,
      title: 'Record feedback',
      child: _FeedbackForm(
        propertyId: property.id,
        existing: _all,
        onSave: (f) async {
          final next = [f, ..._all];
          await ComplaintStore.saveFeedback(next);
          if (mounted) setState(() => _all = next);
        },
      ),
    );
  }

  Future<void> _reply(ResidentFeedback f) async {
    await FormSheet.show<void>(
      context,
      title: 'Reply',
      child: _ReplyForm(
        initial: f.ownerReply,
        onSave: (text) async {
          final next = [for (final x in _all) x.id == f.id ? x.withReply(text) : x];
          await ComplaintStore.saveFeedback(next);
          if (mounted) setState(() => _all = next);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final book = _book;
    if (!_loaded || book == null) return const Scaffold(body: LoadingBox());
    final property = book.propertyById(widget.id);
    if (property == null) {
      return const Scaffold(body: EmptyState(icon: Icons.search_off_rounded, title: 'Property not found', message: 'It may have been deleted.'));
    }
    final mine = [for (final f in _all) if (f.propertyId == property.id) f]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final rated = [for (final f in mine) if (f.rating > 0) f.rating];
    final average = rated.isEmpty ? null : rated.fold<int>(0, (t, r) => t + r) / rated.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews and suggestions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _record(property),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Record'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          MonovaCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              average == null
                  ? 'No ratings yet. Residents can give a review, a suggestion, a maintenance request, or feedback on a resolved complaint.'
                  : 'Average rating ${average.toStringAsFixed(1)} from ${rated.length} review${rated.length == 1 ? '' : 's'}.',
              style: TextStyle(color: c.ink, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          if (mine.isEmpty)
            MonovaCard(
              padding: const EdgeInsets.all(14),
              child: Text('Nothing recorded yet.', style: TextStyle(color: c.muted)),
            )
          else
            for (final f in mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MonovaCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(feedbackKindLabel(f.kind), style: const TextStyle(fontWeight: FontWeight.w700))),
                          Text(dayLabel(f.createdAt), style: TextStyle(color: c.muted, fontSize: 12)),
                        ],
                      ),
                      Text('${f.residentName}${f.rating > 0 ? '  ${'★' * f.rating}${'☆' * (5 - f.rating)}' : ''}', style: TextStyle(color: c.muted, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(f.text, style: TextStyle(color: c.ink, height: 1.4)),
                      if (f.ownerReply.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Owner reply: ${f.ownerReply}', style: TextStyle(color: c.muted, fontSize: 12, height: 1.4)),
                      ],
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(onPressed: () => _reply(f), child: Text(f.ownerReply.isEmpty ? 'Reply' : 'Edit reply')),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _FeedbackForm extends StatefulWidget {
  const _FeedbackForm({required this.propertyId, required this.existing, required this.onSave});

  final String propertyId;
  final List<ResidentFeedback> existing;
  final Future<void> Function(ResidentFeedback) onSave;

  @override
  State<_FeedbackForm> createState() => _FeedbackFormState();
}

class _FeedbackFormState extends State<_FeedbackForm> {
  FeedbackKind _kind = FeedbackKind.review;
  int _rating = 0;
  final _name = TextEditingController();
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final problem = feedbackProblem(text: _text.text, kind: _kind, rating: _rating, residentName: _name.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    // The same resident saying the same thing twice on the same day is a duplicate.
    final today = DateTime.now();
    final dup = widget.existing.any((f) =>
        f.propertyId == widget.propertyId &&
        f.kind == _kind &&
        f.residentName.toLowerCase() == _name.text.trim().toLowerCase() &&
        f.text.trim().toLowerCase() == _text.text.trim().toLowerCase() &&
        f.createdAt.year == today.year &&
        f.createdAt.month == today.month &&
        f.createdAt.day == today.day);
    if (dup) {
      setState(() => _error = 'This was already recorded today.');
      return;
    }
    await widget.onSave(ResidentFeedback(
      id: today.microsecondsSinceEpoch.toString(),
      propertyId: widget.propertyId,
      kind: _kind,
      residentName: _name.text.trim(),
      text: _text.text.trim(),
      rating: _kind == FeedbackKind.review ? _rating : 0,
      createdAt: today,
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<FeedbackKind>(
          initialValue: _kind,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [for (final k in FeedbackKind.values) DropdownMenuItem(value: k, child: Text(feedbackKindLabel(k)))],
          onChanged: (v) => setState(() => _kind = v ?? _kind),
        ),
        if (_kind == FeedbackKind.review) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, color: c.accentStart),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Resident name *')),
        const SizedBox(height: 12),
        TextField(controller: _text, maxLines: 4, decoration: const InputDecoration(labelText: 'What they said *')),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense, height: 1.4)),
        ],
        const SizedBox(height: 14),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _ReplyForm extends StatefulWidget {
  const _ReplyForm({required this.initial, required this.onSave});

  final String initial;
  final Future<void> Function(String) onSave;

  @override
  State<_ReplyForm> createState() => _ReplyFormState();
}

class _ReplyFormState extends State<_ReplyForm> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(controller: _text, maxLines: 3, decoration: const InputDecoration(labelText: 'Your reply', helperText: 'The resident\'s own words stay unchanged')),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () async {
            await widget.onSave(_text.text.trim());
            if (context.mounted) Navigator.of(context).pop();
          },
          child: const Text('Save reply'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Room QR code

/// A QR code for one room. Scanning it with any phone's camera opens WhatsApp to the hostel number,
/// with the room already filled in. The resident does not need Monova.
class RoomQrSheet extends StatelessWidget {
  const RoomQrSheet({super.key, required this.property, required this.room});

  final Property property;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final message = complaintMessage(
      hostel: property.name,
      room: room.number,
      floorText: floorLabel(room.floor),
      category: 'Other',
      description: 'Please describe the problem',
    );
    final link = whatsappLink(property.phone, message);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Room ${room.number} · ${floorLabel(room.floor)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 6),
        Text(
          link == null
              ? 'Add the hostel\'s WhatsApp number on the property first, then this code can open WhatsApp.'
              : 'Print this and put it in the room. A resident scans it with any phone camera; WhatsApp opens with the room filled in, and they only type the problem.',
          style: TextStyle(color: c.muted, height: 1.45),
        ),
        const SizedBox(height: 14),
        if (link != null)
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(data: link, size: 220, errorCorrectionLevel: QrErrorCorrectLevel.M),
            ),
          ),
        const SizedBox(height: 14),
        if (link != null)
          FilledButton.icon(
            onPressed: () => shareText('Complaint for ${property.name}, Room ${room.number}: $link', subject: 'Room ${room.number} complaint code'),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Share code link'),
          ),
      ],
    );
  }
}
