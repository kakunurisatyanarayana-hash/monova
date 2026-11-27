import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../services/services_screen.dart';

/// Every feature this build offers, on Home, so nothing is hidden behind a second page.
/// Each section is one equal-size tile grid, so tiles line up across sections.
class AllFeaturesCard extends StatelessWidget {
  const AllFeaturesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final offline = ApiConfig.offline;
    final sections = [
      for (final s in allServiceSections)
        if (s.items.any((i) => i.available(offline))) s,
    ];
    return MonovaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Everything in MONOVA',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          for (final section in sections) ...[
            const SizedBox(height: 16),
            Text(
              section.title,
              style: TextStyle(
                color: c.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            EqualTileGrid(
              minTileWidth: 150,
              tileHeight: 96,
              children: [
                for (final item in section.items)
                  if (item.available(offline))
                    _FeatureTile(
                      item: item,
                      onTap: () => context.push(item.route!),
                    ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.item, required this.onTap});

  final ServiceItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Material(
      color: c.raised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        hoverColor: c.accentStart.withValues(alpha: 0.08),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, color: c.accentStart, size: 24),
              const SizedBox(height: 6),
              Text(
                item.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
