import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/finance_calc.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';

/// Offline calculators. Open to everyone, signed in or not.
class ToolsScreen extends ConsumerWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.monova;
    final signedIn = ref.watch(sessionProvider).isSignedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Plan before you commit. These run on your device and need no account.', style: TextStyle(color: c.muted)),
          const SizedBox(height: 16),
          _ToolTile(
            icon: Icons.account_balance_rounded,
            title: 'Loan calculator (India)',
            subtitle: 'EMI, GST on fees, processing and other charges, APR, full schedule. Every loan type compared side by side.',
            onTap: () => context.push('/tools/emi'),
          ),
          _ToolTile(
            icon: Icons.calculate_outlined,
            title: 'Calculator',
            subtitle: 'Basic and scientific calculator with memory, history, degrees and radians.',
            onTap: () => context.push('/tools/calculator'),
          ),
          _ToolTile(
            icon: Icons.receipt_long_rounded,
            title: 'GST calculator',
            subtitle: 'Add GST to a price or remove it from a GST-inclusive price, with CGST and SGST split.',
            onTap: () => context.push('/tools/gst'),
          ),
          _ToolTile(
            icon: Icons.percent_rounded,
            title: 'Interest calculator',
            subtitle: 'Simple and compound interest, growth of savings or the cost of a debt.',
            onTap: () => context.push('/tools/interest'),
          ),
          _ToolTile(
            icon: Icons.call_split_rounded,
            title: 'Split a bill',
            subtitle: 'Split a bill equally, by exact amounts, percentages or shares, and see who pays whom.',
            onTap: () => context.push('/tools/split'),
          ),
          const SizedBox(height: 24),
          if (!signedIn)
            SignInGate(
              title: 'Want your money in one place?',
              message: 'Sign in to save accounts, cards, groups and budgets, and to see your dashboard and insights.',
              actionLabel: 'Sign in or create account',
            ),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MonovaCard(
        onTap: onTap,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(gradient: c.aurora, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: c.onAccent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
  }
}

/// Shown where a feature stores data on the server. Guests see this instead of a dead end.
class SignInGate extends StatelessWidget {
  const SignInGate({super.key, required this.title, required this.message, this.actionLabel = 'Sign in'});

  final String title;
  final String message;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final offline = ApiConfig.offline;
    return MonovaCard(
      gradient: LinearGradient(colors: [c.raised, c.border], begin: Alignment.topLeft, end: Alignment.bottomRight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(offline ? Icons.offline_bolt_rounded : Icons.lock_outline_rounded, color: c.accentStart),
          const SizedBox(height: 10),
          Text(offline ? 'Not in this version' : title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            offline ? 'Accounts, sync and saved records arrive in the full MONOVA release. Every tool here works without an account.' : message,
            style: TextStyle(color: c.muted, fontSize: 13),
          ),
          if (!offline) ...[
            const SizedBox(height: 14),
            FilledButton(onPressed: () => context.push('/auth'), child: Text(actionLabel)),
          ],
        ],
      ),
    );
  }
}

/// Wraps any screen that stores data on the server. Signed-in users see the screen; guests see a sign-in prompt.
class RequiresAccount extends ConsumerWidget {
  const RequiresAccount({super.key, required this.title, required this.child, this.message});

  final String title;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionProvider).isSignedIn) return child;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SignInGate(
            title: 'Sign in to use $title',
            message: message ?? 'This keeps your data safe on the server and in sync. Tools stay free to use without an account.',
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => context.push('/tools'),
            icon: const Icon(Icons.calculate_rounded),
            label: const Text('Open free tools instead'),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.label, required this.value, this.tone = AmountTone.neutral});

  final String label;
  final String value;
  final AmountTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(color: c.muted))),
          AmountText(value, tone: tone, size: 18),
        ],
      ),
    );
  }
}

class EmiCalculatorScreen extends StatefulWidget {
  const EmiCalculatorScreen({super.key});

  @override
  State<EmiCalculatorScreen> createState() => _EmiCalculatorScreenState();
}

class _EmiCalculatorScreenState extends State<EmiCalculatorScreen> {
  final _principal = TextEditingController(text: '1000000');
  final _rate = TextEditingController(text: '8.5');
  final _months = TextEditingController(text: '240');
  EmiResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _principal.dispose();
    _rate.dispose();
    _months.dispose();
    super.dispose();
  }

  void _calculate() {
    try {
      final p = double.parse(_principal.text.replaceAll(',', ''));
      final r = double.parse(_rate.text);
      final m = int.parse(_months.text);
      setState(() {
        _result = FinanceCalc.emi(principal: p, annualRatePercent: r, months: m);
        _error = null;
      });
    } catch (_) {
      setState(() {
        _result = null;
        _error = 'Enter a positive loan amount, a rate of zero or more, and a term in months.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('EMI calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(controller: _principal, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Loan amount', prefixText: '₹ '), onChanged: (_) => _calculate()),
          const SizedBox(height: 12),
          TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Interest rate % per year'), onChanged: (_) => _calculate()),
          const SizedBox(height: 12),
          TextField(controller: _months, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Term (months)'), onChanged: (_) => _calculate()),
          const SizedBox(height: 20),
          if (_error != null) Text(_error!, style: TextStyle(color: c.expense)),
          if (r != null)
            MonovaCard(
              gradient: c.aurora,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly EMI', style: TextStyle(color: c.onAccent.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                  Text(money(r.emi), style: TextStyle(color: c.onAccent, fontSize: 32, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Text('Total interest ${money(r.totalInterest)}', style: TextStyle(color: c.onAccent)),
                  Text('Total payable ${money(r.totalPayable)}', style: TextStyle(color: c.onAccent)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Text('Estimate for planning. Your bank\'s schedule may round differently.', style: TextStyle(color: c.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class InterestCalculatorScreen extends StatefulWidget {
  const InterestCalculatorScreen({super.key});

  @override
  State<InterestCalculatorScreen> createState() => _InterestCalculatorScreenState();
}

class _InterestCalculatorScreenState extends State<InterestCalculatorScreen> {
  final _principal = TextEditingController(text: '100000');
  final _rate = TextEditingController(text: '7');
  final _years = TextEditingController(text: '5');
  bool _compound = true;
  String? _error;
  ({double amount, double interest})? _compoundResult;
  double? _simpleResult;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void dispose() {
    _principal.dispose();
    _rate.dispose();
    _years.dispose();
    super.dispose();
  }

  void _calculate() {
    try {
      final p = double.parse(_principal.text.replaceAll(',', ''));
      final r = double.parse(_rate.text);
      final y = double.parse(_years.text);
      if (p <= 0 || r < 0 || y <= 0) throw ArgumentError('invalid');
      setState(() {
        _compoundResult = FinanceCalc.compound(principal: p, annualRatePercent: r, years: y);
        _simpleResult = FinanceCalc.simpleInterest(principal: p, annualRatePercent: r, years: y);
        _error = null;
      });
    } catch (_) {
      setState(() {
        _error = 'Enter a positive amount, a rate of zero or more, and a time in years.';
        _compoundResult = null;
        _simpleResult = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final cr = _compoundResult;
    final si = _simpleResult;
    final shown = _compound ? (cr?.interest ?? 0) : (si ?? 0);
    final total = _compound ? (cr?.amount ?? 0) : (_principalValue + shown);
    return Scaffold(
      appBar: AppBar(title: const Text('Interest calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SegmentedButton<bool>(
            segments: const [ButtonSegment(value: true, label: Text('Compound (monthly)')), ButtonSegment(value: false, label: Text('Simple'))],
            selected: {_compound},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _compound = s.first),
          ),
          const SizedBox(height: 16),
          TextField(controller: _principal, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Principal', prefixText: '₹ '), onChanged: (_) => _calculate()),
          const SizedBox(height: 12),
          TextField(controller: _rate, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Interest rate % per year'), onChanged: (_) => _calculate()),
          const SizedBox(height: 12),
          TextField(controller: _years, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Time (years)'), onChanged: (_) => _calculate()),
          const SizedBox(height: 20),
          if (_error != null) Text(_error!, style: TextStyle(color: c.expense)),
          if (_error == null)
            MonovaCard(
              child: Column(
                children: [
                  _Result(label: 'Interest earned or owed', value: money(shown), tone: AmountTone.income),
                  _Result(label: 'Total amount', value: money(total)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  double get _principalValue => double.tryParse(_principal.text.replaceAll(',', '')) ?? 0;
}

/// Splits one bill between people on this device. Nothing is stored; use a group after signing in to keep history.
class SplitCalculatorScreen extends StatefulWidget {
  const SplitCalculatorScreen({super.key});

  @override
  State<SplitCalculatorScreen> createState() => _SplitCalculatorScreenState();
}

class _SplitCalculatorScreenState extends State<SplitCalculatorScreen> {
  final _total = TextEditingController(text: '2400');
  final List<TextEditingController> _names = [TextEditingController(text: 'You'), TextEditingController(text: 'Bo'), TextEditingController(text: 'Cy')];
  final List<TextEditingController> _values = [TextEditingController(), TextEditingController(), TextEditingController()];
  final List<bool> _included = [true, true, true];
  int _payer = 0;
  String _mode = 'equal';
  String? _error;
  List<String> _lines = [];
  List<({int index, int cents})> _shares = [];

  @override
  void dispose() {
    _total.dispose();
    for (final c in [..._names, ..._values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _addPerson() {
    setState(() {
      _names.add(TextEditingController(text: 'Person ${_names.length + 1}'));
      _values.add(TextEditingController());
      _included.add(true);
    });
  }

  void _calculate() {
    try {
      final total = double.parse(_total.text.replaceAll(',', ''));
      final totalCents = (total * 100).round();
      final idx = [for (var i = 0; i < _names.length; i++) if (_included[i]) i];
      if (idx.length < 2) throw ArgumentError('Pick at least two people to split with.');
      final values = [for (final i in idx) _mode == 'equal' ? null : double.tryParse(_values[i].text.trim())];
      final cents = FinanceCalc.splitCents(totalCents: totalCents, mode: _mode, values: values);

      final shares = [for (var k = 0; k < idx.length; k++) (index: idx[k], cents: cents[k])];
      final net = <String, int>{};
      for (final s in shares) {
        net[s.index.toString()] = (net[s.index.toString()] ?? 0) - s.cents;
      }
      net[_payer.toString()] = (net[_payer.toString()] ?? 0) + totalCents;
      final payments = FinanceCalc.settle(net);

      String nameOf(String key) {
        final i = int.parse(key);
        final n = _names[i].text.trim();
        return n.isEmpty ? 'Person ${i + 1}' : n;
      }

      setState(() {
        _error = null;
        _shares = shares;
        _lines = payments.isEmpty
            ? ['Everyone is settled.']
            : [for (final p in payments) '${nameOf(p.from)} pays ${nameOf(p.to)} ${money(p.cents / 100)}'];
      });
    } catch (e) {
      setState(() {
        _error = e is ArgumentError ? (e.message as String? ?? 'Check the amounts.') : 'Check the amounts.';
        _lines = [];
        _shares = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(title: const Text('Split a bill')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(controller: _total, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Bill total', prefixText: '₹ ')),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _payer,
            decoration: const InputDecoration(labelText: 'Who paid the bill?'),
            items: [for (var i = 0; i < _names.length; i++) DropdownMenuItem(value: i, child: Text(_names[i].text.trim().isEmpty ? 'Person ${i + 1}' : _names[i].text.trim()))],
            onChanged: (v) => setState(() => _payer = v ?? 0),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'equal', label: Text('Equal')),
              ButtonSegment(value: 'exact', label: Text('Exact')),
              ButtonSegment(value: 'percent', label: Text('%')),
              ButtonSegment(value: 'shares', label: Text('Shares')),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _names.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Checkbox(value: _included[i], onChanged: (v) => setState(() => _included[i] = v ?? false)),
                  Expanded(child: TextField(controller: _names[i], decoration: const InputDecoration(isDense: true, labelText: 'Name'), onChanged: (_) => setState(() {}))),
                  if (_mode != 'equal') ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _values[i],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(isDense: true, labelText: _mode == 'percent' ? '%' : (_mode == 'shares' ? 'Shares' : 'Amount')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          TextButton.icon(onPressed: _addPerson, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Add a person')),
          const SizedBox(height: 8),
          FilledButton(onPressed: _calculate, child: const Text('Calculate')),
          const SizedBox(height: 16),
          if (_error != null) Text(_error!, style: TextStyle(color: c.expense)),
          if (_shares.isNotEmpty) ...[
            MonovaCard(
              child: Column(
                children: [
                  for (final s in _shares)
                    _Result(label: _names[s.index].text.trim().isEmpty ? 'Person ${s.index + 1}' : _names[s.index].text.trim(), value: money(s.cents / 100)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MonovaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Who pays whom', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final l in _lines) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text(l)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
