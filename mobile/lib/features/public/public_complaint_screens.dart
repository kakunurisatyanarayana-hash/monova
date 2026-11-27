import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/cloud.dart';
import '../../core/complaints.dart';
import '../../core/property_store.dart';
import '../../core/public_complaints.dart';
import '../../core/theme.dart';

/// The page a room's QR code opens. The resident chooses one of two ways to send their complaint:
///  - WhatsApp: a message to the hostel with the room filled in. Their name and phone go only into that message.
///  - Monova directly: the complaint goes to the hostel's complaint list. No name or phone is sent with it.
class ComplaintFormPage extends StatefulWidget {
  const ComplaintFormPage({
    super.key,
    required this.code,
    required this.room,
    required this.floor,
    this.phone = '',
    this.hostelName = '',
  });

  /// Empty until QR complaints are turned on for the hostel. Then only the WhatsApp option is offered.
  final String code;
  final String room;
  final int floor;

  /// The hostel's WhatsApp number, digits only, from the QR link.
  final String phone;
  final String hostelName;

  @override
  State<ComplaintFormPage> createState() => _ComplaintFormPageState();
}

enum _Route { whatsapp, direct }

class _ComplaintFormPageState extends State<ComplaintFormPage> {
  String? _hostelName;
  String? _ownerUid;
  bool _loading = true;
  bool _sending = false;
  _Route? _route;
  String _category = complaintCategories.first;
  final _description = TextEditingController();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  String? _error;
  String? _ticket;
  String? _trackUrl;
  bool _whatsAppOpened = false;

  @override
  void initState() {
    super.initState();
    _hostelName = widget.hostelName.isEmpty ? null : widget.hostelName;
    _loadHostel();
  }

  @override
  void dispose() {
    _description.dispose();
    _name.dispose();
    _contact.dispose();
    super.dispose();
  }

  /// Gets the hostel's name and owner for the direct route. Failure only disables that route.
  Future<void> _loadHostel() async {
    if (widget.code.isEmpty || !cloudReady) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance.collection('hostels').doc(widget.code).get();
      final data = snap.data();
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (data != null) {
          _hostelName = '${data['name'] ?? _hostelName ?? 'Hostel'}';
          _ownerUid = '${data['ownerUid'] ?? ''}';
        }
      });
    } catch (e) {
      debugPrint('Complaint form could not load the hostel: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _directAvailable => widget.code.isNotEmpty && _ownerUid != null && _ownerUid!.isNotEmpty;

  String get _hostel => _hostelName ?? 'the hostel';

  Future<void> _sendWhatsApp() async {
    final problem = publicComplaintProblem(room: widget.room, category: _category, description: _description.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final message = complaintMessage(
      hostel: _hostel,
      room: widget.room,
      floorText: floorLabel(widget.floor),
      category: _category,
      description: _description.text.trim(),
      resident: _name.text.trim(),
    );
    final contact = _contact.text.trim();
    final text = contact.isEmpty ? message : '$message\nContact: $contact';
    final link = whatsappLink(widget.phone, text);
    if (link == null) {
      setState(() => _error = 'The hostel\'s WhatsApp number is not set. Use the direct option, or tell the hostel in person.');
      return;
    }
    setState(() => _error = null);
    final opened = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    if (!mounted) return;
    setState(() => _whatsAppOpened = opened);
  }

  Future<void> _sendDirect() async {
    final problem = publicComplaintProblem(room: widget.room, category: _category, description: _description.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final owner = _ownerUid ?? '';
    if (owner.isEmpty) {
      setState(() => _error = 'This hostel is not set up for direct complaints yet. Use WhatsApp instead.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final random = math.Random.secure();
    final token = newTrackToken(random);
    final ticket = publicTicket(random);
    final now = DateTime.now().toIso8601String();
    try {
      // Only the room, floor, category, problem and dates are sent. No name or phone number.
      await FirebaseFirestore.instance.collection('complaints').doc(token).set({
        'hostel': widget.code,
        'ticket': ticket,
        'room': widget.room,
        'floor': widget.floor,
        'category': _category,
        'description': _description.text.trim(),
        'status': ComplaintStatus.open.name,
        'createdAt': now,
        'updatedAt': now,
        'resolution': '',
        'ownerUid': owner,
      });
      if (!mounted) return;
      setState(() {
        _sending = false;
        _ticket = ticket;
        _trackUrl = trackLink(CloudConfig.hostingBase, token);
      });
    } on FirebaseException catch (e) {
      debugPrint('Complaint form could not send: ${e.code}');
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.code == 'resource-exhausted'
            ? 'The complaint service is busy today. Please try again later, or use WhatsApp.'
            : 'The complaint was not sent. Check your connection and try again, or use WhatsApp.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(title: const Text('Submit a complaint')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(_hostel, style: TextStyle(color: c.ink, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 4),
          Text('Room ${widget.room} · ${floorLabel(widget.floor)}', style: TextStyle(color: c.muted)),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 30), child: Center(child: CircularProgressIndicator()))
          else if (_ticket != null) ...[
            Text('Thank you. Your complaint was sent.', style: TextStyle(color: c.ink, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            Text('Reference: $_ticket', style: TextStyle(color: c.ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Keep this link to check the status later:', style: TextStyle(color: c.muted, height: 1.4)),
            const SizedBox(height: 6),
            SelectableText(_trackUrl ?? '', style: TextStyle(color: c.accentStart, fontSize: 13)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                if (_trackUrl != null) await Clipboard.setData(ClipboardData(text: _trackUrl!));
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status link copied')));
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy status link'),
            ),
          ] else if (_route == null) ...[
            Text('How would you like to send it?', style: TextStyle(color: c.ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _RouteTile(
              icon: Icons.chat_rounded,
              title: 'Send by WhatsApp',
              text: widget.phone.isEmpty
                  ? 'Not available yet: the hostel has not added its WhatsApp number. Ask the hostel to add it, then reprint the room code.'
                  : 'Opens WhatsApp to the hostel with your message filled in. You press Send there. Works on phones and on computers.',
              onTap: widget.phone.isEmpty
                  ? null
                  : () => setState(() {
                        _route = _Route.whatsapp;
                        _error = null;
                      }),
            ),
            const SizedBox(height: 10),
            _RouteTile(
              icon: Icons.send_rounded,
              title: 'Send directly to Monova',
              text: 'The complaint goes to the hostel\'s list at once. Your name and phone are not sent.',
              onTap: _directAvailable
                  ? () => setState(() {
                        _route = _Route.direct;
                        _error = null;
                      })
                  : null,
            ),
          ] else ...[
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() {
                    _route = null;
                    _error = null;
                    _whatsAppOpened = false;
                  }),
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Change'),
                ),
                const SizedBox(width: 4),
                Text(_route == _Route.whatsapp ? 'Via WhatsApp' : 'Directly to Monova', style: TextStyle(color: c.muted, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 22),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'What is the problem about?'),
              items: [for (final cat in complaintCategories) DropdownMenuItem(value: cat, child: Text(cat))],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Describe the problem', hintText: 'For example: water leaking under the bathroom tap'),
            ),
            if (_route == _Route.whatsapp) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your name (optional)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contact,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Your phone (optional)', helperText: 'Included only in the WhatsApp message'),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Your name and phone are not sent with a direct complaint. The hostel knows the room.',
                style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: c.expense, height: 1.4)),
            ],
            if (_route == _Route.whatsapp && _whatsAppOpened) ...[
              const SizedBox(height: 10),
              Text('WhatsApp is open with your message. Press Send there to finish. Nothing is sent until you do.', style: TextStyle(color: c.ink, height: 1.4)),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _sending ? null : (_route == _Route.whatsapp ? _sendWhatsApp : _sendDirect),
              child: Text(_route == _Route.whatsapp ? 'Open WhatsApp' : (_sending ? 'Sending…' : 'Send to Monova')),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  const _RouteTile({required this.icon, required this.title, required this.text, required this.onTap});

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final enabled = onTap != null;
    return Material(
      color: c.glassFill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: enabled ? c.accentStart : c.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(color: enabled ? c.ink : c.muted, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(text, style: TextStyle(color: c.muted, fontSize: 12, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page a resident opens from their status link. It shows the complaint's status and any resolution note.
class ComplaintStatusPage extends StatefulWidget {
  const ComplaintStatusPage({super.key, required this.token});

  final String token;

  @override
  State<ComplaintStatusPage> createState() => _ComplaintStatusPageState();
}

class _ComplaintStatusPageState extends State<ComplaintStatusPage> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!cloudReady || widget.token.length < 20) {
      setState(() {
        _loading = false;
        _error = 'This status link is not valid.';
      });
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance.collection('complaints').doc(widget.token).get();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _data = snap.data();
        if (_data == null) _error = 'No complaint was found for this link.';
      });
    } catch (e) {
      debugPrint('Status page could not load: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'The status could not be loaded. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('Complaint status')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Text(_error!, style: TextStyle(color: c.ink, height: 1.45))
          else if (d != null) ...[
            Text('Reference ${d['ticket'] ?? ''}', style: TextStyle(color: c.ink, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            Text('Status: ${_statusText('${d['status'] ?? ''}')}', style: TextStyle(color: c.ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Room ${d['room'] ?? ''} · ${d['category'] ?? ''}', style: TextStyle(color: c.muted)),
            const SizedBox(height: 4),
            Text('Reported ${_shortDate('${d['createdAt'] ?? ''}')} · Last update ${_shortDate('${d['updatedAt'] ?? ''}')}', style: TextStyle(color: c.muted, fontSize: 12)),
            if ('${d['resolution'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('What was done', style: TextStyle(color: c.ink, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('${d['resolution']}', style: TextStyle(color: c.ink, height: 1.45)),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
              child: const Text('Refresh status'),
            ),
          ],
        ],
      ),
    );
  }

  static String _statusText(String s) => switch (s) {
        'open' => 'Received',
        'acknowledged' => 'Acknowledged by the hostel',
        'inProgress' => 'Being worked on',
        'resolved' => 'Resolved',
        'closed' => 'Closed',
        _ => s,
      };

  static String _shortDate(String iso) {
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final l = t.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
  }
}
