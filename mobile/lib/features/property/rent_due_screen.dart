import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/property_store.dart';
import '../../core/rent_status.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Rent that needs attention, grouped by property, then floor, then room, so the owner sees the building at a glance.
/// Filters: all, overdue, due today, due soon. Each row opens that tenant's page.
class RentDueScreen extends StatefulWidget {
  const RentDueScreen({super.key});

  @override
  State<RentDueScreen> createState() => _RentDueScreenState();
}

class _RentDueScreenState extends State<RentDueScreen> {
  PropertyBook _book = const PropertyBook();
  bool _loaded = false;
  RentDueKind? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await PropertyStore.load();
    if (!mounted) return;
    setState(() {
      _book = b;
      _loaded = true;
    });
  }

  static String _kindLabel(RentDueKind k) => switch (k) {
    RentDueKind.overdue => 'Overdue',
    RentDueKind.today => 'Due today',
    RentDueKind.soon => 'Due soon',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final today = DateTime.now();
    final all = rentDueRows(_book, today);
    final rows = [
      for (final r in all)
        if (_filter == null || r.kind == _filter) r,
    ];

    // Group: property -> floor -> room (rooms in number order).
    final byProperty = <String, List<RentDueRow>>{};
    for (final r in rows) {
      byProperty.putIfAbsent(r.tenancy.propertyId, () => []).add(r);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rent due')),
      body: !_loaded
          ? const LoadingBox()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('All (${all.length})'),
                      selected: _filter == null,
                      onSelected: (_) => setState(() => _filter = null),
                    ),
                    for (final k in RentDueKind.values)
                      ChoiceChip(
                        label: Text(
                          '${_kindLabel(k)} (${all.where((r) => r.kind == k).length})',
                        ),
                        selected: _filter == k,
                        onSelected: (_) => setState(() => _filter = k),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (rows.isEmpty)
                  EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'No rent needs attention',
                    message: 'Nothing is overdue or due in the next few days.',
                  ),
                for (final entry in byProperty.entries) ...[
                  Text(
                    _book.propertyById(entry.key)?.name ?? 'Property',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  ..._floors(entry.value, c),
                  const SizedBox(height: 14),
                ],
              ],
            ),
    );
  }

  List<Widget> _floors(List<RentDueRow> rows, MonovaColors c) {
    final floors = {for (final r in rows) r.room?.floor ?? 0}.toList()..sort();
    final out = <Widget>[];
    for (final f in floors) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 4),
          child: Text(
            floorLabel(f),
            style: TextStyle(
              color: c.muted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      );
      final floorRows = [
        for (final r in rows)
          if ((r.room?.floor ?? 0) == f) r,
      ]..sort((a, b) => (a.room?.number ?? '').compareTo(b.room?.number ?? ''));
      for (final r in floorRows) {
        out.add(_tile(r, c));
        out.add(const SizedBox(height: 8));
      }
    }
    return out;
  }

  Widget _tile(RentDueRow r, MonovaColors c) {
    final color = switch (r.kind) {
      RentDueKind.overdue => c.expense,
      RentDueKind.today => c.expense,
      RentDueKind.soon => c.warning,
    };
    return MonovaCard(
      padding: const EdgeInsets.all(12),
      onTap: () => context.push('/person/${r.tenancy.personId}'),
      child: Row(
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              r.room?.number ?? '-',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.tenancy.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${money(r.status.owedCents / 100)} due ${dayLabel(r.status.dueOn)}',
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            _kindLabel(r.kind),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.muted),
        ],
      ),
    );
  }
}
