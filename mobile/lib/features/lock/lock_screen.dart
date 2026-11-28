import 'package:monova_app/core/input_rules.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_lock.dart';
import '../../core/local_erase.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// The app locks itself after this long without any touch, click or scroll (when a PIN is set).
const autoLockAfter = Duration(minutes: 2);

/// Shows the lock screen when a PIN is set and the app is closed, in the background, or idle for [autoLockAfter].
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> with WidgetsBindingObserver {
  Timer? _idle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restartIdle();
  }

  @override
  void dispose() {
    _idle?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Every touch, click, drag or scroll restarts the countdown. When it runs out, the app locks if a PIN is set.
  void _restartIdle() {
    _idle?.cancel();
    _idle = Timer(autoLockAfter, () {
      if (mounted) ref.read(appLockProvider.notifier).lockIfSet();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _idle?.cancel();
      ref.read(appLockProvider.notifier).lockIfSet();
    } else if (state == AppLifecycleState.resumed) {
      _restartIdle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(appLockProvider).status;
    if (status == LockStatus.checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final content = status == LockStatus.locked ? const LockScreen() : widget.child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _restartIdle(),
      onPointerMove: (_) => _restartIdle(),
      onPointerSignal: (_) => _restartIdle(),
      child: content,
    );
  }
}

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  static const _minLength = 4;
  static const _maxLength = 6;

  String _pin = '';
  String? _message;
  bool _busy = false;

  void _press(String digit) {
    if (_busy || _pin.length >= _maxLength) return;
    setState(() {
      _pin += digit;
      _message = null;
    });
  }

  void _backspace() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _submit() {
    if (_busy || _pin.length < _minLength) return;
    _unlock();
  }

  Future<void> _unlock() async {
    setState(() => _busy = true);
    final problem = await ref.read(appLockProvider.notifier).tryUnlock(_pin);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (problem != null) {
        _pin = '';
        _message = problem;
      }
    });
  }

  Future<void> _eraseEverything() async {
    final typed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _EraseConfirm(),
    );
    if (typed != true) return;
    await eraseLocalData();
    await ref.read(appLockProvider.notifier).forgetAll();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final failures = ref.watch(appLockProvider).failures;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(gradient: c.aurora, shape: BoxShape.circle),
                    child: Icon(Icons.lock_rounded, color: c.onAccent, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text('Enter your PIN', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text('MONOVA is locked.', style: TextStyle(color: c.muted)),
                  const SizedBox(height: 22),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Always show one dot per allowed digit (6), so a 6-digit PIN shows 6 places.
                      for (var i = 0; i < _maxLength; i++)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i < _pin.length ? c.accentStart : Colors.transparent,
                            border: Border.all(color: i < _pin.length ? c.accentStart : c.border, width: 1.5),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 22,
                    child: Text(_message ?? '', style: TextStyle(color: c.expense, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 8),
                  _Keypad(onDigit: _press, onBackspace: _backspace, onSubmit: _submit),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: (_busy || _pin.length < _minLength) ? null : _unlock,
                      child: Text(_busy ? 'Checking...' : 'Unlock'),
                    ),
                  ),
                  if (failures >= 3) ...[
                    const SizedBox(height: 8),
                    Text('Forgot the PIN? The only way back in is to erase this app\'s data on this device.',
                        textAlign: TextAlign.center, style: TextStyle(color: c.muted, fontSize: 12, height: 1.4)),
                  ],
                  TextButton(
                    onPressed: _eraseEverything,
                    child: Text('Erase data and remove PIN', style: TextStyle(color: c.expense)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onDigit, required this.onBackspace, required this.onSubmit});

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'ok', '0', 'back'];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        for (final k in keys)
          if (k == 'ok')
            _KeyButton(
              onTap: onSubmit,
              child: Icon(Icons.check_rounded, color: context.monova.accentStart),
            )
          else if (k == 'back')
            _KeyButton(
              onTap: onBackspace,
              child: Icon(Icons.backspace_outlined, color: context.monova.muted),
            )
          else
            _KeyButton(
              onTap: () => onDigit(k),
              child: Text(k, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            ),
      ],
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Material(
      color: c.raised,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: c.border)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(child: child),
      ),
    );
  }
}

class _EraseConfirm extends StatefulWidget {
  @override
  State<_EraseConfirm> createState() => _EraseConfirmState();
}

class _EraseConfirmState extends State<_EraseConfirm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _controller.text.trim() == 'ERASE';
    return AlertDialog(
      title: const Text('Erase all data?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Passwords, cards, bills and calculator history on this device will be deleted, and the PIN removed. '
            'This cannot be undone. A backup you made earlier can be restored afterwards.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Type ERASE to confirm'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: context.monova.expense),
          onPressed: ready ? () => Navigator.pop(context, true) : null,
          child: const Text('Erase'),
        ),
      ],
    );
  }
}

/// Sets a new PIN: 4 to 6 digits, typed twice.
class PinSetupSheet extends StatefulWidget {
  const PinSetupSheet({super.key});

  @override
  State<PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends State<PinSetupSheet> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _save() {
    final pin = _pin.text;
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      setState(() => _error = 'Use 4 to 6 digits.');
      return;
    }
    if (pin != _confirm.text) {
      setState(() => _error = 'The two PINs do not match.');
      return;
    }
    Navigator.of(context).pop(pin);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _pin,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'New PIN (4 to 6 digits)', prefixIcon: Icon(Icons.lock_outline_rounded)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirm,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(labelText: 'Type the PIN again', prefixIcon: Icon(Icons.lock_outline_rounded)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: c.expense)),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: const Text('Set PIN')),
        const SizedBox(height: 8),
        Text(
          'The PIN is needed each time you open MONOVA. If you forget it, the only way back in is to erase the data on this device.',
          style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

/// Settings entry: sets a PIN when none is set, or turns the PIN off after the current one is typed.
Future<void> togglePinFromSettings(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final state = ref.read(appLockProvider);
  if (state.status == LockStatus.disabled) {
    final pin = await FormSheet.show<String>(context, title: 'Set an app PIN', child: const PinSetupSheet());
    if (pin == null) return;
    await ref.read(appLockProvider.notifier).setPin(pin);
    messenger.showSnackBar(const SnackBar(content: Text('PIN set. MONOVA will ask for it when you open it.')));
    return;
  }
  final current = await showDialog<String>(
    context: context,
    builder: (ctx) => _CurrentPinDialog(),
  );
  if (current == null) return;
  if (!await PinStore.matches(current)) {
    messenger.showSnackBar(const SnackBar(content: Text('That PIN is not right.')));
    return;
  }
  await ref.read(appLockProvider.notifier).removePin();
  messenger.showSnackBar(const SnackBar(content: Text('PIN turned off.')));
}

class _CurrentPinDialog extends StatefulWidget {
  @override
  State<_CurrentPinDialog> createState() => _CurrentPinDialogState();
}

class _CurrentPinDialogState extends State<_CurrentPinDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Turn off the PIN'),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Current PIN'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Turn off')),
      ],
    );
  }
}
