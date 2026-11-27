import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/attention.dart';
import '../../core/entry_store.dart';
import '../../core/money_plans.dart';
import '../../core/notify.dart';
import '../../core/reminders.dart';
import '../../core/property_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// The first thing on Home: what needs attention today. It hides itself into one calm line when nothing is due.
class AttentionCard extends StatefulWidget {
  const AttentionCard({super.key});

  @override
  State<AttentionCard> createState() => _AttentionCardState();
}

class _AttentionCardState extends State<AttentionCard> {
  List<AttentionItem> _items = const [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final purchases = await EntryStore.loadPurchases();
      final (book, _) = await PropertyStore.loadWithRetention(DateTime.now());
      final now = DateTime.now();
      await PlansStore.runRecurring(now);
      final reminders = await ReminderStore.load();
      // Keep phone alerts in step with the saved reminders each time Home opens. Safe to repeat.
      if (reminderAlertsSupported) {
        for (final r in reminders) {
          await scheduleReminderAlert(r);
        }
      }
      final items = [
        ...attentionItems(purchases: purchases, book: book, today: now),
        ...reminderAttentionItems(reminders, now),
      ];
      if (mounted) setState(() {
        _items = items;
        _loaded = true;
      });
    } catch (_) {
      // A damaged record must not break the Home page; the card just shows nothing to do.
      if (mounted) setState(() => _loaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    if (!_loaded) return const SizedBox.shrink();
    if (_items.isEmpty) {
      return MonovaCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: c.income),
            const SizedBox(width: 10),
            Expanded(child: Text('Nothing needs your attention today.', style: TextStyle(color: c.muted))),
          ],
        ),
      );
    }
    final shown = _items.take(4).toList();
    return MonovaCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Needs attention', style: Theme.of(context).textTheme.titleMedium)),
              if (_items.length > shown.length)
                Text('+${_items.length - shown.length} more', style: TextStyle(color: c.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in shown)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                await context.push(item.route);
                if (mounted) _load();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.urgent ? c.expense : c.warning,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(item.detail, style: TextStyle(color: c.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: c.muted),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
