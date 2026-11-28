import 'package:flutter/material.dart';

import 'theme.dart';

/// Quick yearly rates to tap, so the person does not have to type them. Choosing one fills the rate box.
/// The box still accepts any rate the person types.
class RatePresets extends StatelessWidget {
  const RatePresets({
    super.key,
    required this.controller,
    this.onPicked,
    this.presets = const [0, 6, 12, 18, 24, 36],
  });

  final TextEditingController controller;
  final VoidCallback? onPicked;
  final List<double> presets;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final current = double.tryParse(controller.text.trim());
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick rate (a year)',
              style: TextStyle(
                color: c.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in presets)
                  ChoiceChip(
                    label: Text(p == 0 ? 'No interest' : '${_fmt(p)}%'),
                    selected: current == p,
                    onSelected: (_) {
                      controller.text = _fmt(p);
                      onPicked?.call();
                    },
                  ),
              ],
            ),
          ],
        );
      },
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
