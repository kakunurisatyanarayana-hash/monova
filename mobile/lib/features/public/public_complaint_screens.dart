import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/cloud.dart';
import '../../core/complaints.dart';
import '../../core/property_store.dart';
import '../../core/public_complaints.dart';
import '../../core/theme.dart';

/// The page a room's QR code opens. Anyone can use it, with no app and no account. It sends the complaint straight
/// to the shared store under the hostel's owner, and shows a reference and a status link.
class ComplaintFormPage extends StatefulWidget {
  const ComplaintFormPage({super.key, required this.code, required this.room, required this.floor});

  final String code;
  final String room;
  final int floor;

  @override
  State<ComplaintFormPage> createState() => _ComplaintFormPageState();
}

class _ComplaintFormPageState extends State<ComplaintFormPage> {
  String? _hostelName;
  String? _ownerUid;
  String? _loadError;
  bool _loading = true;
  bool _sending = false;
  String _category = complaintCategories.first;
  final _description = TextEditingController();
  String? _error;
  String? _ticket;
  String? _trackUrl;

  @override
  void initState() {
    super.initState();
    _loadHostel();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _loadHostel() async {
    if (!cloudReady) {
      setState(() {
        _loading = false;
        _loadError = 'This complaint form is not available right now. Please tell the hostel directly.';
      });
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance.collection('hostels').doc(widget.code).get();
      final data = snap.data();
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (data == null) {
          _loadError = 'This QR code is not linked to a hostel any more. Please tell the hostel directly.';
        } else {
          _hostelName = '${data['name'] ?? 'Hostel'}';
          _ownerUid = '${data['ownerUid'] ?? ''}';
        }
      });
    } catch (e) {
      debugPrint('Complaint form could not load the hostel: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'The form could not reach the hostel right now. Check your connection and open the link again.';
      });
    }
  }

  Future<void> _send() async {
    final problem = publicComplaintProblem(room: widget.room, category: _category, description: _description.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final owner = _ownerUid;
    if (owner == null || owner.isEmpty) {
      setState(() => _error = 'The hostel is not ready for complaints yet.');
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
            ? 'The hostel\'s complaint service is busy today. Please try again later or tell the hostel directly.'
            : 'The complaint was not sent. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (_loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
          else if (_loadError != null)
            Text(_loadError!, style: TextStyle(color: c.ink, height: 1.45))
          else if (_ticket != null) ...[
            Text('Thank you. Your complaint was sent.', style: TextStyle(color: c.ink, fontWeight: FontWeight.w800, fontSize: 17)),
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
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status link copied')));
                }
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy status link'),
            ),
          ] else ...[
            Text(_hostelName ?? 'Hostel', style: TextStyle(color: c.ink, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 4),
            Text('Room ${widget.room} · ${floorLabel(widget.floor)}', style: TextStyle(color: c.muted)),
            const SizedBox(height: 16),
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
            const SizedBox(height: 8),
            Text(
              'Please do not write your name or phone number here. The hostel already knows which room this is.',
              style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: c.expense, height: 1.4)),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: Text(_sending ? 'Sending…' : 'Send complaint'),
            ),
          ],
        ],
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
            OutlinedButton(onPressed: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _load();
            }, child: const Text('Refresh status')),
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
