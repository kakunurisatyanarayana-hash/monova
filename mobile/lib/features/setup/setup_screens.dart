import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/profile_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Asked once, on the first open: your name and contact details. Also used to edit the profile later.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key, this.editing = false});

  /// True when opened from Settings (edit), false on the first open.
  final bool editing;

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.editing) {
      final p = ref.read(profileProvider).profile;
      if (p != null) {
        _name.text = p.name;
        _phone.text = p.phone;
        _email.text = p.email;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name. It is used as "you" in bills and groups.');
      return;
    }
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'That email does not look right. Check it, or leave it empty.');
      return;
    }
    await ref.read(profileProvider.notifier).set(LocalProfile(name: name, phone: _phone.text.trim(), email: email));
    if (!mounted) return;
    if (widget.editing) {
      Navigator.of(context).maybePop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      children: [
        if (!widget.editing) ...[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(gradient: c.aurora, shape: BoxShape.circle),
            child: Icon(Icons.account_balance_wallet_rounded, color: c.onAccent, size: 30),
          ),
          const SizedBox(height: 18),
          Text('Welcome to MONOVA', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Tell us your name and contact details once. They are used for you in splits, groups and bills, '
            'and they stay on this device.',
            style: TextStyle(color: c.muted, height: 1.45),
          ),
          const SizedBox(height: 24),
        ],
        MonovaCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(textInputAction: TextInputAction.next, 
                controller: _name,
                autofocus: !widget.editing,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(textInputAction: TextInputAction.next, 
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(textInputAction: TextInputAction.next, 
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.mail_outline_rounded)),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: c.expense)),
              ],
              const SizedBox(height: 16),
              FilledButton(onPressed: _save, child: Text(widget.editing ? 'Save profile' : 'Continue')),
            ],
          ),
        ),
        if (!widget.editing) ...[
          const SizedBox(height: 14),
          Text(
            'You can change these later in Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
        ],
      ],
    );
    if (widget.editing) {
      return Scaffold(appBar: AppBar(title: const Text('Your profile')), body: body);
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: body),
        ),
      ),
    );
  }
}
