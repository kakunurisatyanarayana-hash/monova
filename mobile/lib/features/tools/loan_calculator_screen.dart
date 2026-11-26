import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/loan_calc.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../core/date_calc.dart';
import '../../shared/date_inputs.dart';
import 'saved_loan_scenarios.dart';

/// Loan calculator for India: any loan type, processing and service fees with 18% GST, insurance and stamp duty,
/// effective APR, a full schedule and a side-by-side comparison of every product.
class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  // -1 means no loan type chosen yet. Nothing is calculated, and no sample figures are shown, until the user picks one or types numbers.
  int _product = -1;
  final _amount = TextEditingController();
  final _rate = TextEditingController();
  final _tenure = TextEditingController();
  final _processing = TextEditingController();
  final _serviceFees = TextEditingController(text: '0');
  final _otherCharges = TextEditingController(text: '0');
  bool _gstOnFees = true;
  TermUnit _termUnit = TermUnit.months;
  DateTime? _startOn;
  bool _showSchedule = false;
  bool _showMonthly = false;

  LoanResult? _result;
  String? _error;

  @override
  void dispose() {
    for (final c in [_amount, _rate, _tenure, _processing, _serviceFees, _otherCharges]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyProduct(int index) {
    final p = LoanProduct.all[index];
    _product = index;
    _rate.text = p.ratePercent.toString();
    _tenure.text = p.tenureMonths.toString();
    _termUnit = TermUnit.months;
    _processing.text = p.processingFeePercent.toString();
    _calculate();
  }

  double get _tenureValue => double.tryParse(_tenure.text.trim()) ?? 0;
  int get _tenureMonths => DateCalc.termToMonths(_tenureValue, _termUnit);

  double _num(TextEditingController c) => double.tryParse(c.text.replaceAll(',', '').trim()) ?? double.nan;

  void _calculate() {
    // Nothing to show until a loan type is chosen and an amount is typed.
    if (_product < 0 || _amount.text.trim().isEmpty) {
      setState(() {
        _result = null;
        _error = null;
      });
      return;
    }
    final principal = _num(_amount);
    final rate = _num(_rate);
    final tenure = _tenureMonths;
    final processing = _num(_processing);
    final services = _num(_serviceFees);
    final other = _num(_otherCharges);
    final product = LoanProduct.all[_product];

    if (principal.isNaN || principal <= 0) return _fail('Enter the loan amount.');
    if (rate.isNaN || rate < 0 || rate > 40) return _fail('Enter an interest rate between 0% and 40%.');
    if (tenure < 1 || tenure > 600) return _fail('Enter a tenure between 1 and 600 months.');
    if (tenure > product.maxTenureMonths) {
      return _fail('${product.name} usually runs up to ${product.maxTenureMonths} months. You can still calculate, but check with the lender.', soft: true);
    }
    if (processing.isNaN || processing < 0 || services.isNaN || services < 0 || other.isNaN || other < 0) {
      return _fail('Fees must be zero or positive.');
    }

    try {
      final result = LoanCalculator.calculate(LoanInput(
        principal: principal,
        annualRatePercent: rate,
        tenureMonths: tenure,
        charges: LoanCharges(
          processingFeePercent: processing,
          documentationFee: services,
          insurancePremium: other,
          applyGstOnServiceFees: _gstOnFees,
        ),
      ));
      setState(() {
        _result = result;
        _error = null;
      });
    } catch (e) {
      _fail('Check the inputs and try again.');
    }
  }

  void _fail(String message, {bool soft = false}) {
    setState(() {
      _error = message;
      if (!soft) _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final r = _result;
    final product = _product < 0 ? null : LoanProduct.all[_product];
    return Scaffold(
      appBar: AppBar(title: const Text('Loan calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // All loan types visible at once (wraps to rows), so no scrolling is needed to reach any of them.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < LoanProduct.all.length; i++)
                _productTile(i, c),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            product == null
                ? 'Choose a loan type above. Its typical rate, tenure and fee will fill in, and you can change them.'
                : '${product.note} Defaults are indicative. Edit anything to match your sanction letter.',
            style: TextStyle(color: c.muted, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _field(_amount, 'Loan amount', prefix: '₹ ', onChanged: _calculate),
          Row(children: [
            Expanded(child: _field(_rate, 'Interest % per year', onChanged: _calculate)),
            const SizedBox(width: 12),
            Expanded(
              child: TermInput(
                controller: _tenure,
                unit: _termUnit,
                label: 'Loan term',
                onUnitChanged: (u) => setState(() {
                  _termUnit = u;
                  _calculate();
                }),
                onChanged: _calculate,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          DateSelector(
            label: 'Loan start date (optional, shows the end date)',
            value: _startOn,
            firstYear: 1990,
            onChanged: (d) => setState(() => _startOn = d),
          ),
          const SizedBox(height: 12),
          Text('Charges', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _field(_processing, 'Processing fee %', onChanged: _calculate)),
            const SizedBox(width: 12),
            Expanded(child: _field(_serviceFees, 'Documentation, valuation, legal (₹)', prefix: '₹ ', onChanged: _calculate)),
          ]),
          const SizedBox(height: 12),
          _field(_otherCharges, 'Insurance and stamp duty (₹, no GST)', prefix: '₹ ', onChanged: _calculate),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _gstOnFees,
            onChanged: (v) => setState(() {
              _gstOnFees = v;
              _calculate();
            }),
            title: const Text('Apply 18% GST on service fees'),
            subtitle: Text('GST applies to processing and service fees. Interest and stamp duty carry no GST.',
                style: TextStyle(color: c.muted, fontSize: 12)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: c.warning, fontWeight: FontWeight.w600)),
          ],
          if (r != null) ...[
            const SizedBox(height: 12),
            MonovaCard(
              gradient: c.hero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly EMI', style: TextStyle(color: c.onAccent.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                  Text(money(r.emi), style: TextStyle(color: c.onAccent, fontSize: 32, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('APR ${r.effectiveAnnualRatePercent.toStringAsFixed(2)}% · stated ${_rate.text}%',
                      style: TextStyle(color: c.onAccent, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MonovaCard(
              child: Column(
                children: [
                  _line('Loan amount', money(_num(_amount)), c),
                  if (_startOn != null) _line('Ends on', dayLabel(DateCalc.termEnd(_startOn!, _tenureValue, _termUnit)), c),
                  _line('Total interest over $_tenureMonths months', money(r.totalInterest), c, tone: AmountTone.warning),
                  const Divider(),
                  _line('Processing fee', money(r.serviceFees - _num(_serviceFees).clamp(0, double.infinity)), c),
                  _line('Documentation, valuation and legal', money(_num(_serviceFees)), c),
                  _line(_gstOnFees ? 'GST on service fees (18%)' : 'GST (switched off)', money(r.gstOnFees), c),
                  _line('Insurance and stamp duty', money(r.otherCharges), c),
                  const Divider(),
                  _line('Total upfront charges', money(r.upfrontCharges), c, tone: AmountTone.expense),
                  _line('Net amount you receive', money(r.netDisbursed), c, tone: AmountTone.income),
                  _line('Total you pay back (EMIs + upfront)', money(r.totalCost), c, bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SectionTitle(_showSchedule ? 'Repayment schedule' : 'Repayment schedule', action: _showSchedule ? 'Hide' : 'Show', onAction: () => setState(() => _showSchedule = !_showSchedule)),
            if (_showSchedule) _scheduleView(r, c),
            const SizedBox(height: 16),
            const SectionTitle('All loan types, same amount'),
            const SizedBox(height: 8),
            _comparison(_num(_amount), c),
          ],
          const SizedBox(height: 16),
          SavedLoanScenarios(snapshot: _snapshot, onLoad: _loadSnapshot),
          const SizedBox(height: 16),
          Text(
            'Estimates only. Home, personal, car and two-wheeler rates come from public bank listings checked in November 2026. Interest on loans is GST-exempt; processing and service fees carry 18% GST. Stamp duty and actual rates depend on the lender, your profile and your state. Verify with the lender before you sign.',
            style: TextStyle(color: c.muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// Current inputs, saved as a scenario.
  Map<String, dynamic> _snapshot() => {
        'product': _product,
        'amount': _amount.text,
        'rate': _rate.text,
        'tenure': _tenure.text,
        'processing': _processing.text,
        'services': _serviceFees.text,
        'other': _otherCharges.text,
        'gst': _gstOnFees,
        'unit': _termUnit.name,
      };

  /// Restores a saved scenario's inputs and recalculates.
  void _loadSnapshot(Map<String, dynamic> s) {
    setState(() {
      final index = (s['product'] as num?)?.toInt() ?? 0;
      _product = index.clamp(0, LoanProduct.all.length - 1);
      _amount.text = '${s['amount'] ?? ''}';
      _rate.text = '${s['rate'] ?? ''}';
      _tenure.text = '${s['tenure'] ?? ''}';
      _processing.text = '${s['processing'] ?? ''}';
      _serviceFees.text = '${s['services'] ?? ''}';
      _otherCharges.text = '${s['other'] ?? ''}';
      _gstOnFees = s['gst'] == true;
      _termUnit = TermUnit.values.firstWhere((u) => u.name == s['unit'], orElse: () => TermUnit.months);
    });
    _calculate();
  }

  Widget _productTile(int i, MonovaColors c) {
    final p = LoanProduct.all[i];
    final selected = i == _product;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _applyProduct(i)),
      child: Container(
        width: 104,
        height: 88,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: selected ? c.aurora : null,
          color: selected ? null : c.raised,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? Colors.transparent : c.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_iconFor(p.icon), color: selected ? c.onAccent : c.accentStart),
            const SizedBox(height: 6),
            Text(p.name, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: selected ? c.onAccent : c.ink, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _scheduleView(LoanResult r, MonovaColors c) {
    final years = <int, List<LoanScheduleRow>>{};
    for (final row in r.schedule) {
      years.putIfAbsent((row.month - 1) ~/ 12 + 1, () => []).add(row);
    }
    return Column(
      children: [
        SegmentedButton<bool>(
          segments: const [ButtonSegment(value: false, label: Text('Yearly')), ButtonSegment(value: true, label: Text('Monthly'))],
          selected: {_showMonthly},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _showMonthly = s.first),
        ),
        const SizedBox(height: 10),
        if (!_showMonthly)
          for (final y in years.entries)
            _rowTile(
              'Year ${y.key}',
              'Interest ${money(y.value.fold<double>(0, (a, b) => a + b.interest))} · Principal ${money(y.value.fold<double>(0, (a, b) => a + b.principal))}',
              'Balance ${money(y.value.last.balance)}',
              c,
            )
        else
          for (final row in r.schedule.take(120))
            _rowTile('Month ${row.month} · EMI ${money(row.emi)}',
                'Interest ${money(row.interest)} · Principal ${money(row.principal)}', 'Balance ${money(row.balance)}', c),
        if (_showMonthly && r.schedule.length > 120)
          Text('Showing the first 120 months. The last month closes the loan at ${money(r.schedule.last.balance)}.',
              style: TextStyle(color: c.muted, fontSize: 12)),
      ],
    );
  }

  Widget _comparison(double amount, MonovaColors c) {
    final rows = LoanCalculator.compareAll(amount);
    return MonovaCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final row in rows)
            ListTile(
              leading: CircleAvatar(backgroundColor: c.border, child: Icon(_iconFor(row.product.icon), color: c.accentStart, size: 18)),
              title: Text(row.product.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${row.product.ratePercent}% · ${row.product.tenureMonths ~/ 12} yrs · fee ${row.product.processingFeePercent}%\n'
                'Interest ${money(row.result.totalInterest)} · APR ${row.result.effectiveAnnualRatePercent.toStringAsFixed(2)}%',
                style: TextStyle(color: c.muted, fontSize: 12),
              ),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AmountText(money(row.result.emi), size: 14),
                  Text('EMI', style: TextStyle(color: c.muted, fontSize: 11)),
                ],
              ),
              onTap: () => setState(() => _applyProduct(LoanProduct.all.indexOf(row.product))),
            ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, {String? prefix, VoidCallback? onChanged, bool integer = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.numberWithOptions(decimal: !integer),
        decoration: InputDecoration(labelText: label, prefixText: prefix),
        onChanged: (_) => onChanged?.call(),
      ),
    );
  }

  Widget _line(String label, String value, MonovaColors c, {AmountTone tone = AmountTone.neutral, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: c.muted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          AmountText(value, tone: tone, size: 14),
        ]),
      );

  Widget _rowTile(String title, String subtitle, String trailing, MonovaColors c) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: MonovaCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(subtitle, style: TextStyle(color: c.muted, fontSize: 12)),
              ]),
            ),
            Text(trailing, style: TextStyle(color: c.muted, fontSize: 12)),
          ]),
        ),
      );

  IconData _iconFor(String key) => switch (key) {
        'home' => Icons.home_rounded,
        'person' => Icons.person_rounded,
        'car' => Icons.directions_car_rounded,
        'bike' => Icons.two_wheeler_rounded,
        'school' => Icons.school_rounded,
        'business' => Icons.business_center_rounded,
        'property' => Icons.apartment_rounded,
        'gold' => Icons.monetization_on_rounded,
        _ => Icons.account_balance_rounded,
      };
}
