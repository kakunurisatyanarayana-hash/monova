import 'package:flutter/material.dart';

import '../../core/complaints.dart';
import '../../core/theme.dart';

/// Complaint counts by status, one tile each. Statuses still needing work are red while they have any.
/// Tapping a tile calls [onPick] with its status; [selected] outlines the tile whose filter is on.
class ComplaintStatusTiles extends StatelessWidget {
  const ComplaintStatusTiles({
    super.key,
    required this.complaints,
    required this.onPick,
    this.selected,
  });

  final List<Complaint> complaints;
  final void Function(ComplaintStatus status) onPick;
  final ComplaintStatus? selected;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final counts = ComplaintCounts.of(complaints);
    final items = <(ComplaintStatus, String, int)>[
      (ComplaintStatus.open, 'New (open)', counts.open),
      (ComplaintStatus.acknowledged, 'Acknowledged', counts.acknowledged),
      (ComplaintStatus.inProgress, 'In progress', counts.inProgress),
      (ComplaintStatus.resolved, 'Resolved', counts.resolved),
      (ComplaintStatus.closed, 'Closed', counts.closed),
    ];
    final tileWidth = MediaQuery.sizeOf(context).width >= 600 ? 150.0 : 132.0;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final (status, label, count) in items)
          _StatusTile(
            label: label,
            count: count,
            alert:
                count > 0 &&
                status != ComplaintStatus.resolved &&
                status != ComplaintStatus.closed,
            outlined: selected == status,
            width: tileWidth,
            onTap: () => onPick(status),
            c: c,
          ),
      ],
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.label,
    required this.count,
    required this.alert,
    required this.outlined,
    required this.width,
    required this.onTap,
    required this.c,
  });

  final String label;
  final int count;
  final bool alert;
  final bool outlined;
  final double width;
  final VoidCallback onTap;
  final MonovaColors c;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: alert ? c.expense : c.glassFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: outlined ? c.accentStart : (alert ? c.expense : c.border),
          width: outlined ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: TextStyle(
                    color: alert ? Colors.white : c.ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: alert
                        ? Colors.white.withValues(alpha: 0.9)
                        : c.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
