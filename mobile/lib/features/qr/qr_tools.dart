import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/qr_payloads.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../property/map_picker.dart';
import 'qr_common.dart';

/// Monova QR: wedding invitations, location codes, guest entry, any code, and scanning.
class QrHubScreen extends StatelessWidget {
  const QrHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    Widget tile(IconData icon, String title, String subtitle, String route) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: MonovaCard(
            padding: const EdgeInsets.all(14),
            onTap: () => context.push(route),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: c.accentStart.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: c.accentStart),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: c.muted, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.muted),
              ],
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Monova QR')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          MonovaCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Make and scan QR codes on this phone. Nothing needs an account or an internet connection, except opening a map or a web link.',
              style: TextStyle(color: c.muted, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          tile(Icons.celebration_outlined, 'Wedding invitations', 'Invitation card with a QR code, shared as a picture or PDF', '/qr/invites'),
          tile(Icons.place_outlined, 'Location code', 'A map code for a venue, hotel or meeting place', '/qr/location'),
          tile(Icons.qr_code_2_rounded, 'Make any code', 'Text, web link, contact card, Wi-Fi, business or payment link', '/qr/make'),
          tile(Icons.qr_code_scanner_rounded, 'Scan a code', 'Read a code with the camera. Links open only when you confirm', '/qr/scan'),
        ],
      ),
    );
  }
}

/// A map code for a place: a map link (works in any map app) or a standard location code, with directions and parking.
class LocationQrScreen extends StatefulWidget {
  const LocationQrScreen({super.key});

  @override
  State<LocationQrScreen> createState() => _LocationQrScreenState();
}

class _LocationQrScreenState extends State<LocationQrScreen> {
  final _name = TextEditingController();
  final _directions = TextEditingController();
  final _parking = TextEditingController();
  final _cardKey = GlobalKey();
  LatLng? _point;
  bool _mapLink = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _directions.dispose();
    _parking.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final pick = await Navigator.of(context).push<MapPick>(MaterialPageRoute(builder: (_) => MapPickerScreen(initial: _point)));
    if (pick == null || !mounted) return;
    setState(() {
      _point = pick.point;
      _error = null;
    });
  }

  String? _payload() {
    final p = _point;
    if (p == null) return null;
    return _mapLink ? mapLinkPayload(p.latitude, p.longitude) : geoPayload(p.latitude, p.longitude, label: _name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final payload = _payload();
    final problem = payload == null ? null : payloadProblem(payload);
    final info = [
      if (_directions.text.trim().isNotEmpty) 'Directions: ${_directions.text.trim()}',
      if (_parking.text.trim().isNotEmpty) 'Parking: ${_parking.text.trim()}',
    ].join('\n');
    return Scaffold(
      appBar: AppBar(title: const Text('Location code')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Place name (for example Garden Hall)'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.map_outlined, size: 18),
            label: Text(_point == null ? 'Pick the place on the map' : 'Place chosen · change'),
          ),
          if (_point != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Lat ${_point!.latitude.toStringAsFixed(5)}, Lng ${_point!.longitude.toStringAsFixed(5)}',
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          TextField(controller: _directions, minLines: 1, maxLines: 3, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Directions (optional)'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          TextField(controller: _parking, decoration: const InputDecoration(labelText: 'Parking (optional)'), onChanged: (_) => setState(() {})),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Map link')),
              ButtonSegment(value: false, label: Text('Map app code')),
            ],
            selected: {_mapLink},
            onSelectionChanged: (s) => setState(() => _mapLink = s.first),
          ),
          const SizedBox(height: 6),
          Text(
            _mapLink
                ? 'A map link opens in the map app the guest uses.'
                : 'A location code is read directly by map apps that support it.',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
          if (problem != null) ...[
            const SizedBox(height: 10),
            Text(problem, style: TextStyle(color: c.expense)),
          ],
          if (payload != null && problem == null) ...[
            const SizedBox(height: 16),
            QrCard(payload: payload, boundaryKey: _cardKey, title: _name.text.trim().isEmpty ? 'Location' : _name.text.trim(), subtitle: info, size: 220),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final png = await captureQrPng(_cardKey);
                if (png != null) await shareQrPng(png, fileName: 'location.png', text: 'Location: ${_name.text.trim()}');
              },
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share as picture'),
            ),
          ],
          if (_error != null) Text(_error!, style: TextStyle(color: c.expense)),
        ],
      ),
    );
  }
}

/// Makes a code for any content: text, a web link, a contact card, Wi-Fi, business details, profile or listing or payment links.
class MakeQrScreen extends StatefulWidget {
  const MakeQrScreen({super.key});

  @override
  State<MakeQrScreen> createState() => _MakeQrScreenState();
}

class _MakeQrScreenState extends State<MakeQrScreen> {
  static const _kinds = <String>[
    'Text',
    'Web link',
    'Contact card',
    'Wi-Fi',
    'Business details',
    'Personal profile link',
    'Property or service listing link',
    'Payment link',
  ];

  String _kind = 'Text';
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _c = TextEditingController();
  String _security = 'WPA';
  final _cardKey = GlobalKey();
  String? _error;
  String? _payload;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    super.dispose();
  }

  String get _label => switch (_kind) {
        'Text' => 'Text',
        'Web link' || 'Personal profile link' || 'Property or service listing link' || 'Payment link' => 'Web address (https://…)',
        'Contact card' => 'Name',
        'Wi-Fi' => 'Network name (SSID)',
        'Business details' => 'Business name',
        _ => '',
      };

  void _make() {
    String? problem;
    String? payload;
    final a = _a.text.trim();
    switch (_kind) {
      case 'Text':
        if (a.isEmpty) problem = 'Type the text to put in the code.';
        payload = a;
      case 'Web link' || 'Personal profile link' || 'Property or service listing link' || 'Payment link':
        final uri = Uri.tryParse(a);
        if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http') || uri.host.isEmpty) {
          problem = 'Enter a full web address that starts with https://';
        }
        payload = a;
      case 'Contact card':
        if (a.isEmpty) problem = 'Enter the name.';
        payload = contactPayload(name: a, phone: _b.text.trim(), email: _c.text.trim());
      case 'Wi-Fi':
        if (a.isEmpty) problem = 'Enter the network name.';
        if (_security != 'nopass' && _b.text.isEmpty) problem = 'Enter the Wi-Fi password, or choose Open network.';
        payload = wifiPayload(ssid: a, password: _b.text, security: _security);
      case 'Business details':
        if (a.isEmpty) problem = 'Enter the business name.';
        payload = contactPayload(name: a, phone: _b.text.trim(), email: _c.text.trim(), organisation: a);
    }
    if (problem == null && payload != null) problem = payloadProblem(payload);
    setState(() {
      _error = problem;
      _payload = problem == null ? payload : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final showSecond = _kind == 'Contact card' || _kind == 'Business details' || _kind == 'Wi-Fi';
    final secondLabel = switch (_kind) {
      'Wi-Fi' => 'Password',
      'Contact card' || 'Business details' => 'Phone',
      _ => '',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Make a code')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _kind,
            decoration: const InputDecoration(labelText: 'What is the code for?'),
            items: [for (final k in _kinds) DropdownMenuItem(value: k, child: Text(k))],
            onChanged: (v) => setState(() {
              _kind = v ?? _kind;
              _payload = null;
              _error = null;
            }),
          ),
          const SizedBox(height: 12),
          if (_label.isNotEmpty)
            TextField(controller: _a, keyboardType: _kind.contains('link') || _kind == 'Payment link' ? TextInputType.url : TextInputType.text, decoration: InputDecoration(labelText: _label)),
          if (showSecond) ...[
            const SizedBox(height: 12),
            TextField(controller: _b, obscureText: false, keyboardType: _kind == 'Wi-Fi' ? TextInputType.visiblePassword : TextInputType.phone, decoration: InputDecoration(labelText: secondLabel)),
          ],
          if (_kind == 'Contact card' || _kind == 'Business details') ...[
            const SizedBox(height: 12),
            TextField(controller: _c, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email (optional)')),
          ],
          if (_kind == 'Wi-Fi') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _security,
              decoration: const InputDecoration(labelText: 'Security'),
              items: const [
                DropdownMenuItem(value: 'WPA', child: Text('WPA or WPA2 (most networks)')),
                DropdownMenuItem(value: 'WEP', child: Text('WEP (old networks)')),
                DropdownMenuItem(value: 'nopass', child: Text('Open network (no password)')),
              ],
              onChanged: (v) => setState(() => _security = v ?? _security),
            ),
          ],
          if (_kind == 'Payment link')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Use a web page that takes the payment (https). Payment apps\' own links (upi://) are not made into codes, because scanners refuse them.',
                style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
              ),
            ),
          const SizedBox(height: 14),
          FilledButton(onPressed: _make, child: const Text('Make the code')),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: c.expense)),
          ],
          if (_payload != null) ...[
            const SizedBox(height: 16),
            QrCard(payload: _payload!, boundaryKey: _cardKey, title: _kind, subtitle: '', size: 220),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                final png = await captureQrPng(_cardKey);
                if (png != null) await shareQrPng(png, fileName: 'monova-code.png');
              },
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share as picture'),
            ),
          ],
        ],
      ),
    );
  }
}
