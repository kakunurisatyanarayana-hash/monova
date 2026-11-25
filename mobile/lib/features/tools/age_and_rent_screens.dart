import 'package:flutter/material.dart';

import '../../core/date_calc.dart';
import '../../core/format.dart';
import '../../core/horoscope.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../shared/date_inputs.dart';

/// Exact age from a date of birth, on any date you choose. Results appear once a birth date is picked.
class AgeCalculatorScreen extends StatefulWidget {
  const AgeCalculatorScreen({super.key});

  @override
  State<AgeCalculatorScreen> createState() => _AgeCalculatorScreenState();
}

class _AgeCalculatorScreenState extends State<AgeCalculatorScreen> {
  DateTime? _birth;
  DateTime _on = DateCalc.dayOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    String? error;
    AgeResult? result;
    if (_birth != null) {
      try {
        result = AgeCalc.between(birth: _birth!, on: _on);
      } on ArgumentError catch (e) {
        error = e.message as String?;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Age calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          DateSelector(
            label: 'Date of birth',
            value: _birth,
            firstYear: 1900,
            onChanged: (d) => setState(() => _birth = d),
          ),
          const SizedBox(height: 18),
          DateSelector(
            label: 'Calculate age on',
            value: _on,
            firstYear: 1900,
            onChanged: (d) => setState(() => _on = d),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _on = DateCalc.dayOnly(DateTime.now())),
              icon: const Icon(Icons.today_rounded, size: 18),
              label: const Text('Use today'),
            ),
          ),
          const SizedBox(height: 12),
          if (_birth == null)
            MonovaCard(child: Text('Pick a date of birth to see the exact age.', style: TextStyle(color: c.muted)))
          else if (error != null)
            Text(error, style: TextStyle(color: c.expense, fontWeight: FontWeight.w600))
          else if (result != null) ...[
            MonovaCard(
              gradient: c.aurora,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Exact age', style: TextStyle(color: c.onAccent.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('${result.years} years', style: TextStyle(color: c.onAccent, fontSize: 32, fontWeight: FontWeight.w800)),
                  Text('${result.months} months, ${result.days} days', style: TextStyle(color: c.onAccent, fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MonovaCard(
              child: Column(
                children: [
                  _row('Total days', '${result.totalDays}', c),
                  _row('Total weeks', '${result.totalWeeks}', c),
                  _row('Total months', '${result.totalMonths}', c),
                  _row('Born on a', result.bornOn, c),
                  const Divider(),
                  _row('Next birthday', dayLabel(result.nextBirthday), c),
                  _row('Days until next birthday', '${result.daysToNextBirthday}', c),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _BirthDetails(report: horoscopeFor(_birth!)),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, MonovaColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: c.muted))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}

/// Birth details worked out from the date alone: Western and Vedic sun sign, Chinese zodiac, life path number.
class _BirthDetails extends StatelessWidget {
  const _BirthDetails({required this.report});

  final HoroscopeReport report;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final w = report.western;
    return MonovaCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Birth details', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _detail(c, 'Western sun sign', '${w.name} (${w.dates})', 'Element ${w.element} · ruled by ${w.ruler}'),
          _detail(c, 'Vedic sun sign', report.vedic, 'Approximate. Your moon sign needs the birth time and place.'),
          _detail(c, 'Chinese zodiac', '${report.chineseElement} ${report.chineseAnimal}', 'Based on the calendar year.'),
          _detail(c, 'Life path number', '${report.lifePath}', report.lifePathMeaning),
          const SizedBox(height: 10),
          Text(w.traits, style: TextStyle(color: c.ink, height: 1.4)),
          const SizedBox(height: 10),
          Text(
            'Worked out from the date of birth on this device. It is for fun and self-reflection, not advice.',
            style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _detail(MonovaColors c, String label, String value, String note) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text(note, style: TextStyle(color: c.muted, fontSize: 12)),
          ],
        ),
      );
}

/// Rent over a period, with a yearly increase. Shows total rent, the rent at the end, and each year.
class RentCalculatorScreen extends StatefulWidget {
  const RentCalculatorScreen({super.key});

  @override
  State<RentCalculatorScreen> createState() => _RentCalculatorScreenState();
}

class _RentCalculatorScreenState extends State<RentCalculatorScreen> {
  final _rent = TextEditingController();
  final _increase = TextEditingController();
  final _term = TextEditingController();
  final _deposit = TextEditingController();
  TermUnit _unit = TermUnit.months;
  DateTime? _start;

  @override
  void dispose() {
    for (final c in [_rent, _increase, _term, _deposit]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final rent = double.tryParse(_rent.text.replaceAll(',', '').trim());
    final increase = double.tryParse(_increase.text.trim()) ?? 0;
    final termValue = double.tryParse(_term.text.trim());
    final deposit = double.tryParse(_deposit.text.replaceAll(',', '').trim()) ?? 0;

    RentResult? result;
    String? error;
    if (rent != null && termValue != null && termValue > 0) {
      final months = DateCalc.termToMonths(termValue, _unit);
      try {
        result = RentCalc.calculate(monthlyRent: rent, yearlyIncreasePercent: increase, months: months);
      } on ArgumentError catch (e) {
        error = e.message as String?;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rent calculator')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _rent,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Monthly rent', prefixText: '₹ '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _increase,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Increase every year (%)'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TermInput(
            controller: _term,
            unit: _unit,
            label: 'Lease length',
            onUnitChanged: (u) => setState(() => _unit = u),
            onChanged: () => setState(() {}),
          ),
          DateSelector(
            label: 'Lease start date (optional)',
            value: _start,
            firstYear: 1990,
            onChanged: (d) => setState(() => _start = d),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _deposit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Security deposit (optional)', prefixText: '₹ '),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          if (error != null) Text(error, style: TextStyle(color: c.expense, fontWeight: FontWeight.w600)),
          if (result == null && error == null)
            MonovaCard(child: Text('Enter the monthly rent and the lease length to see the totals.', style: TextStyle(color: c.muted))),
          if (result != null) ...[
            MonovaCard(
              gradient: c.aurora,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total rent for the lease', style: TextStyle(color: c.onAccent.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                  Text(money(result.totalRent), style: TextStyle(color: c.onAccent, fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Rent at the end: ${money(result.finalMonthlyRent)} a month', style: TextStyle(color: c.onAccent)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MonovaCard(
              child: Column(
                children: [
                  _line('Lease length', '${result.months} months', c),
                  if (_start != null)
                    _line('Ends on', dayLabel(DateCalc.termEnd(_start!, termValue!, _unit)), c),
                  if (deposit > 0) _line('Security deposit (returned at the end)', money(deposit), c),
                  if (deposit > 0) _line('Rent plus deposit', money(result.totalRent + deposit), c, bold: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text('Each year', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            MonovaCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final y in result.years)
                    ListTile(
                      title: Text('Year ${y.year}'),
                      subtitle: Text('${money(y.monthlyRent)} a month', style: TextStyle(color: c.muted, fontSize: 12)),
                      trailing: AmountText(money(y.yearTotal), size: 14),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _line(String label, String value, MonovaColors c, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: c.muted, fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
