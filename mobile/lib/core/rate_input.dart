import 'package:monova_app/core/input_rules.dart';
import 'package:flutter/material.dart';

import 'rate_units.dart';
import 'theme.dart';

/// A rate field with the unit picker underneath it and a plain sentence that says what the rate costs.
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

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final typed = double.tryParse(controller.text.trim());
    final annual = typed == null ? null : toAnnualPercent(typed, unit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: amountFormatters,
          decoration: InputDecoration(labelText: unit.fieldLabel),
          onChanged: (_) {
            onChanged?.call();
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<RateUnit>(
          initialValue: unit,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'How is the interest quoted?'),
          items: [for (final u in RateUnit.values) DropdownMenuItem(value: u, child: Text(u.label))],
          onChanged: (v) {
            if (v != null) onUnitChanged(v);
          },
        ),
        if (annual != null && annual >= 0) ...[
          const SizedBox(height: 8),
          Text(plainRateExplanation(annual), style: TextStyle(color: c.muted, fontSize: 12, height: 1.4)),
        ],
      ],
    );
  }
}
