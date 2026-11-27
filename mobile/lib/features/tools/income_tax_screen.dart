import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/income_tax.dart';
import '../../core/input_rules.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Income tax for a salaried person: new and old regime side by side, with HRA, deductions, rebate, surcharge and cess.
class IncomeTaxScreen extends StatefulWidget {
  const IncomeTaxScreen({super.key});

  @override
  State<IncomeTaxScreen> createState() => _IncomeTaxScreenState();
}

class _IncomeTaxScreenState extends State<IncomeTaxScreen> {
  final Map<String, TextEditingController> _fields = {};
  bool _metro = false;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctl(String key) => _fields.putIfAbsent(key, () => TextEditingController());

  /// Whole rupees from a field. Blank or unreadable counts as zero.
  int _rupees(String key) => (double.tryParse((_fields[key]?.text ?? '').replaceAll(',', '').trim()) ?? 0).round();

  TaxInputs get _inputs => TaxInputs(
        salary: _rupees('salary'),
        basic: _rupees('basic'),
        hraReceived: _rupees('hra'),
        rentPaid: _rupees('rent'),
        metroCity: _metro,
        otherIncome: _rupees('other'),
        savingsInterest: _rupees('savings'),
        professionalTax: _rupees('pt'),
        employerNps: _rupees('enps'),
        section80c: _rupees('c80'),
        section80d: _rupees('d80'),
        homeLoanInterest: _rupees('home'),
        npsSelf: _rupees('npsSelf'),
      );

  Widget _amount(String key, String label, {String? helper}) {
    return TextField(
      controller: _ctl(key),
      onChanged: (_) => setState(() {}),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: amountFormatters,
      decoration: InputDecoration(labelText: label, prefixText: '₹ ', helperText: helper, helperMaxLines: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final inputs = _inputs;
    final newR = newRegimeResult(inputs);
    final oldR = oldRegimeResult(inputs);
    final newWins = newR.total <= oldR.total;
    final best = newWins ? newR : oldR;
    final saving = newWins ? oldR.total - newR.total : newR.total - oldR.total;
    final hasIncome = inputs.salary + inputs.otherIncome > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Income tax calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Estimate for an individual in India, $taxRulesYear. Enter yearly amounts. Nothing leaves this phone.',
            style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (hasIncome)
            _ResultCard(best: best, saving: saving, newWins: newWins)
          else
            MonovaCard(
              padding: const EdgeInsets.all(18),
              child: Text(
                'Enter your gross salary to see the tax under each regime.',
                style: TextStyle(color: c.muted, height: 1.4),
              ),
            ),
          const SizedBox(height: 16),
          _Group(
            title: 'Your salary',
            children: [
              _amount('salary', 'Gross salary per year', helper: 'Total before any deduction, as on Form 16 Part A'),
              const SizedBox(height: 12),
              _amount('basic', 'Basic salary per year', helper: 'Used for the HRA and NPS limits'),
              const SizedBox(height: 12),
              _amount('other', 'Other income per year (optional)', helper: 'Rent received, freelance, business profit, interest'),
              const SizedBox(height: 12),
              _amount('savings', 'Savings account interest (optional)', helper: 'Deductible up to 10,000 in the old regime (80TTA)'),
            ],
          ),
          const SizedBox(height: 14),
          _Group(
            title: 'HRA and rent',
            subtitle: 'Used only in the old regime.',
            children: [
              _amount('hra', 'HRA received per year', helper: 'From your salary slip or payroll'),
              const SizedBox(height: 12),
              _amount('rent', 'Rent paid per year', helper: 'Total rent you paid in the year'),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('I live in a metro city'),
                subtitle: const Text('Delhi, Mumbai, Kolkata, Chennai, Hyderabad, Bengaluru, Pune, Ahmedabad'),
                value: _metro,
                onChanged: (v) => setState(() => _metro = v),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Group(
            title: 'Deductions',
            subtitle: 'Old regime only, except employer NPS, which both regimes allow.',
            children: [
              _amount('pt', 'Professional tax paid per year', helper: 'Up to 2,500'),
              const SizedBox(height: 12),
              _amount('c80', '80C: PF, life insurance, ELSS, tuition fees', helper: 'Limit 1,50,000'),
              const SizedBox(height: 12),
              _amount('d80', '80D: health insurance premium', helper: 'Limit 25,000'),
              const SizedBox(height: 12),
              _amount('home', '24(b): home loan interest, own home', helper: 'Limit 2,00,000'),
              const SizedBox(height: 12),
              _amount('npsSelf', '80CCD(1B): NPS you add yourself', helper: 'Limit 50,000'),
              const SizedBox(height: 12),
              _amount('enps', '80CCD(2): employer NPS contribution', helper: 'Limit 10% of basic (old), 14% of basic (new)'),
            ],
          ),
          if (hasIncome) ...[
            const SizedBox(height: 14),
            _CompareCard(newR: newR, oldR: oldR),
            const SizedBox(height: 14),
            _DeductionsCard(newR: newR, oldR: oldR),
          ],
          const SizedBox(height: 16),
          Text(
            'An estimate, not advice. It leaves out other allowances (LTA, meal and telephone), capital gains at special rates, '
            'senior-citizen slabs and surcharge marginal relief. Check your figures on incometax.gov.in or with a tax adviser before you file.',
            style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// A titled group of fields, each group in its own card.
class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children, this.subtitle});

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return MonovaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(subtitle!, style: TextStyle(color: c.muted, fontSize: 12)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.best, required this.saving, required this.newWins});

  final RegimeResult best;
  final int saving;
  final bool newWins;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return MonovaCard(
      gradient: c.hero,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            newWins ? 'Lower tax: New regime' : 'Lower tax: Old regime',
            style: TextStyle(color: c.onAccent.withValues(alpha: 0.85), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(money(best.total.toDouble()), style: TextStyle(color: c.onAccent, fontSize: 32, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          Text(
            'About ${money(best.total / 12)} a month. '
            '${saving == 0 ? 'Both regimes give the same tax.' : 'Saves ${money(saving.toDouble())} a year against the other regime.'}',
            style: TextStyle(color: c.onAccent.withValues(alpha: 0.92), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _CompareCard extends StatelessWidget {
  const _CompareCard({required this.newR, required this.oldR});

  final RegimeResult newR;
  final RegimeResult oldR;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final style = TextStyle(color: c.ink, fontSize: 13);
    final bold = TextStyle(color: c.ink, fontSize: 13, fontWeight: FontWeight.w800);
    Widget row(String label, int Function(RegimeResult) value, {bool strong = false, bool money0 = true}) {
      String cell(RegimeResult r) {
        final v = value(r);
        return money0 ? money(v.toDouble()) : '$v';
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(flex: 4, child: Text(label, style: strong ? bold : style)),
            Expanded(flex: 3, child: _Figure(text: cell(newR), bold: strong)),
            Expanded(flex: 3, child: _Figure(text: cell(oldR), bold: strong)),
          ],
        ),
      );
    }

    final header = TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700);
    return MonovaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Compare the two regimes', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(flex: 4, child: Text('', style: header)),
              Expanded(flex: 3, child: Text('New', textAlign: TextAlign.right, style: header)),
              Expanded(flex: 3, child: Text('Old', textAlign: TextAlign.right, style: header)),
            ],
          ),
          const Divider(height: 12),
          row('Income before deductions', (r) => r.income),
          row('Deductions', (r) => r.income - r.taxable),
          row('Taxable income', (r) => r.taxable),
          row('Tax on slabs', (r) => r.breakdown.slabTax),
          row('Rebate or relief', (r) => -r.breakdown.rebate),
          row('Surcharge', (r) => r.breakdown.surcharge),
          row('Cess (4%)', (r) => r.breakdown.cess),
          const Divider(height: 12),
          row('Total tax a year', (r) => r.total, strong: true),
          row('Per month, estimate', (r) => r.total ~/ 12, strong: true),
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text('Effective rate', style: style)),
                Expanded(flex: 3, child: _Figure(text: _rate(newR), bold: false)),
                Expanded(flex: 3, child: _Figure(text: _rate(oldR), bold: false)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _rate(RegimeResult r) => r.income == 0 ? '0%' : '${(r.total * 100 / r.income).toStringAsFixed(1)}%';
}

/// A right-aligned figure that shrinks rather than wrapping on a narrow phone.
class _Figure extends StatelessWidget {
  const _Figure({required this.text, required this.bold});

  final String text;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Text(text, style: TextStyle(color: c.ink, fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
    );
  }
}

class _DeductionsCard extends StatelessWidget {
  const _DeductionsCard({required this.newR, required this.oldR});

  final RegimeResult newR;
  final RegimeResult oldR;

  @override
  Widget build(BuildContext context) {
    return MonovaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Deductions used', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          _List(title: 'New regime', result: newR),
          const SizedBox(height: 10),
          _List(title: 'Old regime', result: oldR),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.title, required this.result});

  final String title;
  final RegimeResult result;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(color: c.muted, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 4),
          if (result.deductions.isEmpty)
            Text('None', style: TextStyle(color: c.ink, fontSize: 13))
          else
            for (final item in result.deductions)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(item.label, style: TextStyle(color: c.ink, fontSize: 13))),
                    Text(money(item.amount.toDouble()), style: TextStyle(color: c.ink, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
