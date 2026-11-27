import 'dart:math' as math;

import 'package:monova_app/core/input_rules.dart';
import 'package:flutter/material.dart';

import '../core/date_calc.dart';

const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Pick a date three ways: day, month and year dropdowns, or the calendar button. The day is kept valid for the chosen month.
class DateSelector extends StatefulWidget {
  const DateSelector({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstYear = 1900,
    this.lastYear,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final int firstYear;
  final int? lastYear;

  @override
  State<DateSelector> createState() => _DateSelectorState();
}

class _DateSelectorState extends State<DateSelector> {
  int? _day;
  int? _month;
  int? _year;

  @override
  void initState() {
    super.initState();
    _day = widget.value?.day;
    _month = widget.value?.month;
    _year = widget.value?.year;
  }

  int get _lastYear => widget.lastYear ?? DateTime.now().year + 50;

  void _emit() {
    final y = _year;
    final m = _month;
    final d = _day;
    if (y == null || m == null || d == null) return;
    final valid = math.min(d, DateCalc.daysInMonth(y, m));
    if (valid != d) setState(() => _day = valid);
    widget.onChanged(DateTime(y, m, valid));
  }

  Future<void> _pickFromCalendar() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.value ?? DateTime(now.year, now.month, now.day),
      firstDate: DateTime(widget.firstYear),
      lastDate: DateTime(_lastYear, 12, 31),
    );
    if (picked == null) return;
    setState(() {
      _day = picked.day;
      _month = picked.month;
      _year = picked.year;
    });
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final maxDay = (_year != null && _month != null) ? DateCalc.daysInMonth(_year!, _month!) : 31;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(widget.label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<int>(
                key: ValueKey('day-$_day-$maxDay'),
                initialValue: _day,
                isExpanded: true,
                // Narrow fields keep little inner padding, so a two-digit day is not cut to its first digit.
                decoration: const InputDecoration(labelText: 'Day', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                menuMaxHeight: 260,
                items: [for (var d = 1; d <= maxDay; d++) DropdownMenuItem(value: d, child: Text('$d'))],
                onChanged: (v) {
                  setState(() => _day = v);
                  _emit();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: DropdownButtonFormField<int>(
                key: ValueKey('month-$_month'),
                initialValue: _month,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Month', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                menuMaxHeight: 260,
                items: [
                  for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(_monthNames[m - 1])),
                ],
                onChanged: (v) {
                  setState(() => _month = v);
                  _emit();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: DropdownButtonFormField<int>(
                key: ValueKey('year-$_year'),
                initialValue: _year,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Year'),
                menuMaxHeight: 260,
                items: [
                  for (var y = _lastYear; y >= widget.firstYear; y--) DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (v) {
                  setState(() => _year = v);
                  _emit();
                },
              ),
            ),
            IconButton(
              tooltip: 'Open calendar',
              icon: const Icon(Icons.calendar_month_rounded),
              onPressed: _pickFromCalendar,
            ),
          ],
        ),
      ],
    );
  }
}

/// A length of time typed as a number and chosen as days, months or years.
class TermInput extends StatelessWidget {
  const TermInput({
    super.key,
    required this.controller,
    required this.unit,
    required this.onUnitChanged,
    required this.onChanged,
    this.label = 'Term',
  });

  final TextEditingController controller;
  final TermUnit unit;
  final ValueChanged<TermUnit> onUnitChanged;
  final VoidCallback onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.number, inputFormatters: wholeNumberFormatters,
              decoration: InputDecoration(labelText: label),
              onChanged: (_) => onChanged(),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<TermUnit>(
              key: ValueKey('unit-${unit.name}'),
              initialValue: unit,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Unit'),
              menuMaxHeight: 260,
              items: [for (final u in TermUnit.values) DropdownMenuItem(value: u, child: Text(u.label))],
              onChanged: (u) {
                if (u != null) onUnitChanged(u);
              },
            ),
          ),
        ],
      ),
    );
  }
}
