import 'package:flutter/material.dart';

import '../../core/cloud.dart';
import '../../core/cloud_sync.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Owner account for sharing hostel complaints: sign up, email verification, sign in, password reset, sign out.
/// Everything here is optional. The app works offline without it.
class OwnerAccountScreen extends StatefulWidget {
  const OwnerAccountScreen({super.key});

  @override
  State<OwnerAccountScreen> createState() => _OwnerAccountScreenState();
}

class _OwnerAccountScreenState extends State<OwnerAccountScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _message;
  bool _busy = false;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    final n = await CloudSync.pendingCount();
    if (mounted) setState(() => _pending = n);
  }

  Future<void> _run(Future<String> Function() action) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = result;
    });
    await _loadPending();
  }

  Future<void> _syncNow() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final sent = await CloudSync.pushPending(report: (m) {
      if (mounted) setState(() => _message = m);
    });
    // Upload first, then bring in what other phones shared, so both directions happen in one press.
    await CloudSync.pullOwnerComplaints(report: (m) {
      if (mounted) setState(() => _message = m);
    });
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (sent == 0 && _message == null) _message = 'Nothing waiting to be shared.';
    });
    await _loadPending();
  }

  Future<void> _getShared() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    await CloudSync.pullOwnerComplaints(report: (m) {
      if (mounted) setState(() => _message = m);
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final user = OwnerAccount.user;
    final reason = CloudSync.blockedReason();
    return Scaffold(
      appBar: AppBar(title: const Text('Owner account and sharing')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          MonovaCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Sharing is optional. Resident names, phone numbers and emails stay on this phone. Only complaint details (room, category, description, status) and reviews are shared, so that complaints can reach the shared store.',
              style: TextStyle(color: c.muted, height: 1.45, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          MonovaCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              _pending == 0 ? 'No complaints waiting to be shared.' : '$_pending complaint${_pending == 1 ? '' : 's'} saved on this phone, waiting to be shared.',
              style: TextStyle(color: c.ink, fontWeight: FontWeight.w700),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            MonovaCard(
              padding: const EdgeInsets.all(14),
              child: Text(_message!, style: TextStyle(color: c.ink, height: 1.45)),
            ),
          ],
          const SizedBox(height: 16),
          if (!cloudReady)
            MonovaCard(
              padding: const EdgeInsets.all(14),
              child: Text(reason ?? 'Cloud sync is not available.', style: TextStyle(color: c.muted, height: 1.45)),
            )
          else if (user == null) ...[
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(labelText: 'Owner email'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 6 characters for a new account'),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _run(() => OwnerAccount.signIn(_email.text, _password.text)),
                    child: const Text('Sign in'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _run(() => OwnerAccount.register(_email.text, _password.text)),
                    child: const Text('Create account'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => _run(() => OwnerAccount.resetPassword(_email.text)),
              child: const Text('Forgot password? Send a reset link'),
            ),
          ] else ...[
            MonovaCard(
              padding: const EdgeInsets.all(14),
              child: Text(
                user.emailVerified
                    ? 'Signed in as ${user.email}. Email verified.'
                    : 'Signed in as ${user.email}. Email not verified yet, so complaints are not shared. Open the link we sent, then press the button below.',
                style: TextStyle(color: c.ink, height: 1.45),
              ),
            ),
            const SizedBox(height: 12),
            if (!user.emailVerified) ...[
              FilledButton(
                onPressed: _busy ? null : () => _run(OwnerAccount.checkVerified),
                child: const Text('I have verified'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : () => _run(OwnerAccount.resendVerification),
                child: const Text('Send the verification email again'),
              ),
            ] else ...[
              FilledButton(
                onPressed: _busy ? null : _syncNow,
                child: const Text('Share and get complaints now'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _busy ? null : _getShared,
                child: const Text('Only get shared complaints'),
              ),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => _run(() async {
                await OwnerAccount.signOut();
                return 'Signed out. Complaints stay on this phone.';
              }),
              child: const Text('Sign out'),
            ),
          ],
        ],
      ),
    );
  }
}
