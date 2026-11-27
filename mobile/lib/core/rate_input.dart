import 'package:monova_app/core/input_rules.dart';
import 'package:flutter/material.dart';

import 'rate_units.dart';
import 'theme.dart';

/// A rate field with a scroll picker, the unit choice, and a plain sentence that says what the rate costs.
/// The person can scroll to a value, or type one exactly.
class RateInput extends StatelessWidget {
  const RateInput({
    super.key,
    required this.controller,
    required this.unit,
    required this.onUnitChanged,
    this.onChanged,
  });

  final TextEditingController controller;
  final RateUnit unit;
  final ValueChanged<RateUnit> onUnitChanged;
  final VoidCallback? onChanged;

  Future<void> _pick(BuildContext context) async {
    final current = double.tryParse(controller.text.trim()) ?? 0;
    final picked = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (_) => _RateWheel(unit: unit, initial: current),
    );
    if (picked == null) return;
    controller.text = plainRate(picked);
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final typed = double.tryParse(controller.text.trim());
    final annual = typed == null ? null : toAnnualPercent(typed, unit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: amountFormatters,
                decoration: InputDecoration(labelText: unit.fieldLabel),
                onChanged: (_) => onChanged?.call(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: () => _pick(context),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Pick'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<RateUnit>(
          key: ValueKey('unit-$unit'),
          initialValue: unit,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'How is the interest quoted?'),
          items: [for (final u in RateUnit.values) DropdownMenuItem(value: u, child: Text(u.label))],
          onChanged: (v) {
            if (v != null) onUnitChanged(v);
          },
        ),
        if (annual != null && annual >= 0) ...[
          const SizedBox(height: 10),
          Text(plainRateExplanation(annual), style: TextStyle(color: c.muted, fontSize: 12, height: 1.4)),
        ],
      ],
    );
  }
}

/// A scroll wheel of rates for one unit. Returns the value the person chose.
class _RateWheel extends StatefulWidget {
  const _RateWheel({required this.unit, required this.initial});

  final RateUnit unit;
  final double initial;

  @override
  State<_RateWheel> createState() => _RateWheelState();
}

class _RateWheelState extends State<_RateWheel> {
  late final RateRange _range = rateRange(widget.unit);
  late int _index = _range.indexOf(widget.initial);
  late final FixedExtentScrollController _controller = FixedExtentScrollController(initialItem: _index);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _text(double v) => switch (widget.unit) {
        RateUnit.percentYear => '${v.toStringAsFixed(2)} % a year',
        RateUnit.percentMonth => '${v.toStringAsFixed(2)} % a month',
        RateUnit.rupeesPer100Month => '₹ ${v.toStringAsFixed(2)} for every ₹100, a month',
        RateUnit.rupeesPer1000Month => '₹ ${v.toStringAsFixed(1)} for every ₹1,000, a month',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final chosen = _range.valueAt(_index);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.unit.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Scroll to a rate. Each step is ${plainRate(_range.step)}.', style: TextStyle(color: c.muted, fontSize: 12)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: ListWheelScrollView.useDelegate(
                controller: _controller,
                itemExtent: 44,
                diameterRatio: 1.6,
                perspective: 0.003,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (i) => setState(() => _index = i),
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: _range.count,
                  builder: (context, i) {
                    final selected = i == _index;
                    return Center(
                      child: Text(
                        plainRate(_range.valueAt(i)),
                        style: TextStyle(
                          fontSize: selected ? 26 : 18,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected ? c.accentStart : c.muted,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(_text(chosen), textAlign: TextAlign.center, style: TextStyle(color: c.ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(onPressed: () => Navigator.pop(context, chosen), child: const Text('Use this rate'))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
