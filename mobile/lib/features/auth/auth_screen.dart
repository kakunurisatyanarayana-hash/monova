import 'package:monova_app/core/input_rules.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../state/providers.dart';

/// Sign in with a mobile number (one-time code, default) or with email and password. Optional: the app works for guests.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

enum _Method { mobile, email }

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();

  _Method _method = _Method.mobile;
  bool _register = false;
  bool _busy = false;
  bool _obscure = true;
  String? _serverError;

  // Mobile flow state
  bool _codeSent = false;
  String? _sentTo;
  String? _devCode;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_phone, _code, _email, _name, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Turns a user-typed mobile number into E.164. Ten digits default to India (+91).
  String _normalisePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (RegExp(r'^\d{10}$').hasMatch(digits)) return '+91$digits';
    if (digits.startsWith('00')) return '+${digits.substring(2)}';
    return digits;
  }

  String? _validatePhone(String? v) {
    final n = _normalisePhone(v ?? '');
    return RegExp(r'^\+[1-9]\d{7,14}$').hasMatch(n) ? null : 'Enter a valid mobile number, e.g. 98765 43210';
  }

  void _showError(Object e) {
    final message = e is ApiException ? e.message : 'Could not complete this. Check your connection and try again.';
    setState(() => _serverError = message);
  }

  Future<void> _sendCode() async {
    setState(() => _serverError = null);
    if (_validatePhone(_phone.text) != null) {
      _formKey.currentState?.validate();
      return;
    }
    setState(() => _busy = true);
    try {
      final number = _normalisePhone(_phone.text);
      final result = await ref.read(repositoryProvider).requestOtp(number);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _sentTo = result.phoneNumber;
        _devCode = result.devCode;
        _code.clear();
      });
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyCode() async {
    setState(() => _serverError = null);
    if (!RegExp(r'^\d{6}$').hasMatch(_code.text.trim())) {
      setState(() => _serverError = 'Enter the 6-digit code from your SMS.');
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).verifyOtp(
            _sentTo!,
            _code.text.trim(),
            displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
          );
      if (!mounted) return;
      _leave();
    } on ApiException catch (e) {
      final nameError = e.errors?['displayName'];
      if (mounted) {
        setState(() => _serverError = nameError is List && nameError.isNotEmpty
            ? 'This number is new. ${nameError.first}'
            : e.message);
      }
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitEmail() async {
    setState(() => _serverError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final controller = ref.read(sessionProvider.notifier);
    try {
      if (_register) {
        await controller.register(_email.text.trim(), _name.text.trim(), _password.text);
      } else {
        await controller.login(_email.text.trim(), _password.text);
      }
      if (mounted) _leave();
    } on ApiException catch (e) {
      if (mounted) setState(() => _serverError = e.message);
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// 0 to 4, guidance only. The server enforces the real password rules.
  int get _strength {
    final p = _password.text;
    if (p.isEmpty) return 0;
    var score = 0;
    if (p.length >= 8) score++;
    if (p.length >= 12) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: _AuroraBackdrop(colors: c, dark: isDark)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                      ),
                      const _Brand(),
                      const SizedBox(height: 24),
                      _GlassCard(
                        colors: c,
                        dark: isDark,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Segmented<_Method>(
                                colors: c,
                                value: _method,
                                options: const {_Method.mobile: 'Mobile number', _Method.email: 'Email'},
                                onChanged: (m) => setState(() {
                                  _method = m;
                                  _serverError = null;
                                }),
                              ),
                              const SizedBox(height: 22),
                              if (_method == _Method.mobile) _mobilePanel(c) else _emailPanel(c),
                              if (_serverError != null) ...[
                                const SizedBox(height: 14),
                                _ErrorBox(colors: c, message: _serverError!),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _OrDivider(colors: c),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), side: BorderSide(color: c.border)),
                        onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
                        icon: const Icon(Icons.explore_outlined),
                        label: const Text('Continue as guest'),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Passwords are hashed and never stored as text. Codes expire after 5 minutes.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.muted, fontSize: 11, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobilePanel(MonovaColors c) {
    if (!_codeSent) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Enter your mobile number. We will send a one-time code.', style: TextStyle(color: c.muted)),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone, inputFormatters: phoneFormatters,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(labelText: 'Mobile number', prefixText: '+91 ', prefixIcon: Icon(Icons.phone_iphone_rounded)),
            validator: _validatePhone,
          ),
          const SizedBox(height: 20),
          _GradientButton(colors: c, busy: _busy, label: 'Send code', onPressed: _busy ? null : _sendCode),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Code sent to $_sentTo. It expires in 5 minutes.', style: TextStyle(color: c.muted)),
        if (_devCode != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Text('Development only, no SMS sent. Your code is $_devCode', style: TextStyle(color: c.warning, fontWeight: FontWeight.w700)),
          ),
        ],
        const SizedBox(height: 14),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number, inputFormatters: wholeNumberFormatters,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 10),
          decoration: const InputDecoration(labelText: '6-digit code', counterText: ''),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Your name (only for a new number)', prefixIcon: Icon(Icons.person_outline_rounded)),
        ),
        const SizedBox(height: 18),
        _GradientButton(colors: c, busy: _busy, label: 'Verify and continue', onPressed: _busy ? null : _verifyCode),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(onPressed: _busy ? null : () => setState(() => _codeSent = false), child: Text('Change number', style: TextStyle(color: c.muted))),
            TextButton(onPressed: _busy ? null : _sendCode, child: Text('Resend code', style: TextStyle(color: c.accentStart, fontWeight: FontWeight.w700))),
          ],
        ),
      ],
    );
  }

  Widget _emailPanel(MonovaColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Segmented<bool>(
          colors: c,
          value: _register,
          options: const {false: 'Sign in', true: 'Create account'},
          onChanged: (r) => setState(() {
            _register = r;
            _serverError = null;
          }),
        ),
        const SizedBox(height: 18),
        if (_register) ...[
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 14),
        ],
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
          validator: (v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? 'Enter a valid email' : null,
        ),
        const SizedBox(height: 14),
        TextFormField(
          controller: _password,
          obscureText: _obscure,
          autofillHints: const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show password' : 'Hide password',
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Enter your password';
            if (_register && (v.length < 8 || !RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v))) {
              return 'Use 8+ characters with a letter and a digit';
            }
            return null;
          },
        ),
        if (_register && _password.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          _StrengthMeter(score: _strength, colors: c),
        ],
        const SizedBox(height: 22),
        _GradientButton(colors: c, busy: _busy, label: _register ? 'Create account' : 'Sign in', onPressed: _busy ? null : _submitEmail),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.colors, required this.message});

  final MonovaColors colors;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.expense.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.expense.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: colors.expense, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: TextStyle(color: colors.expense, fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.colors});

  final MonovaColors colors;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Divider(color: colors.border)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: colors.muted))),
          Expanded(child: Divider(color: colors.border)),
        ],
      );
}

class _AuroraBackdrop extends StatelessWidget {
  const _AuroraBackdrop({required this.colors, required this.dark});

  final MonovaColors colors;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: colors.base),
        Positioned(top: -120, left: -80, child: _Blob(color: colors.accentStart, size: 320, opacity: dark ? 0.32 : 0.28)),
        Positioned(top: 60, right: -120, child: _Blob(color: colors.accentEnd, size: 300, opacity: dark ? 0.30 : 0.22)),
        Positioned(bottom: -140, left: 40, child: _Blob(color: colors.accentEnd, size: 280, opacity: dark ? 0.18 : 0.12)),
        Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: const SizedBox.expand())),
      ],
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size, required this.opacity});

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
        ),
      );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Column(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            gradient: c.hero,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(color: c.accentStart.withValues(alpha: 0.4), blurRadius: 28, offset: const Offset(0, 10))],
          ),
          child: Center(child: Text('M', style: TextStyle(color: c.onAccent, fontSize: 34, fontWeight: FontWeight.w900))),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (r) => c.aurora.createShader(r),
          child: const Text('MONOVA', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 4, color: Colors.white)),
        ),
        const SizedBox(height: 6),
        Text('Your money, clearly.', style: TextStyle(color: c.muted, fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.colors, required this.dark, required this.child});

  final MonovaColors colors;
  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
          decoration: BoxDecoration(
            color: colors.raised.withValues(alpha: dark ? 0.82 : 0.9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: colors.border),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.35 : 0.08), blurRadius: 40, offset: const Offset(0, 18))],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({required this.colors, required this.value, required this.options, required this.onChanged});

  final MonovaColors colors;
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: colors.base, borderRadius: BorderRadius.circular(18), border: Border.all(color: colors.border)),
      child: Row(
        children: [
          for (final e in options.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(e.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(gradient: e.key == value ? colors.aurora : null, borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: Text(
                    e.value,
                    style: TextStyle(color: e.key == value ? colors.onAccent : colors.muted, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter({required this.score, required this.colors});

  final int score;
  final MonovaColors colors;

  @override
  Widget build(BuildContext context) {
    final labels = ['Too weak', 'Weak', 'Good', 'Strong', 'Excellent'];
    final tones = [colors.expense, colors.warning, colors.warning, colors.income, colors.income];
    return Row(
      children: [
        for (var i = 0; i < 4; i++)
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 4),
              height: 5,
              decoration: BoxDecoration(color: i < score ? tones[score.clamp(0, 4)] : colors.border, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        const SizedBox(width: 10),
        Text(labels[score.clamp(0, 4)], style: TextStyle(color: colors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.colors, required this.label, required this.onPressed, required this.busy});

  final MonovaColors colors;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: onPressed == null && !busy ? 0.6 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: colors.aurora,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: colors.accentStart.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 8))],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onPressed,
            child: Center(
              child: busy
                  ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.onAccent))
                  : Text(label, style: TextStyle(color: colors.onAccent, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.2)),
            ),
          ),
        ),
      ),
    );
  }
}
