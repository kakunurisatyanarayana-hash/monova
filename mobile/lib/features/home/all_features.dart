import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../services/services_screen.dart';

/// Every feature this build offers, on Home, so nothing is hidden behind Explore.
class AllFeaturesCard extends StatelessWidget {
  const AllFeaturesCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final offline = ApiConfig.offline;
    return MonovaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Everything in MONOVA', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final section in allServiceSections) ...[
            if (section.items.any((i) => i.available(offline))) ...[
              if (section.items.length > 1) Text(section.title, style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final item in section.items)
                    if (item.available(offline))
                      Material(
                        color: c.raised,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.border)),
                        child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => context.push(item.route!),
                        child: SizedBox(
                          width: 104,
                          child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            children: [
                              Icon(item.icon, color: c.accentStart, size: 24),
                              const SizedBox(height: 6),
                              Text(item.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          ),
                        ),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: 14),
            ],
          ],
        ],
      ),
    );
  }
}
