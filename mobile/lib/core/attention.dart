import 'complaints.dart';
import 'entry_store.dart';
import 'format.dart';
import 'property_store.dart';
import 'reminders.dart';

/// One item per property that has complaints still open. Each opens that property's complaint list.
List<AttentionItem> complaintAttentionItems(
  List<Complaint> complaints,
  PropertyBook book,
) {
  final items = <AttentionItem>[];
  for (final p in book.properties) {
    final open = complaints
        .where((x) => x.propertyId == p.id && x.isOpen)
        .length;
    if (open == 0) continue;
    items.add(
      AttentionItem(
        title: '$open open complaint${open == 1 ? '' : 's'} at ${p.name}',
        detail: 'Tap to open the complaints',
        route: '/property/${p.id}/complaints',
        urgent: true,
      ),
    );
  }
  return items;
}

/// One thing on the Home screen that needs the user's attention, with the page that deals with it.
class AttentionItem {
  const AttentionItem({
    required this.title,
    required this.detail,
    required this.route,
    required this.urgent,
  });

  final String title;
  final String detail;
  final String route;

  /// Urgent items are shown first.
  final bool urgent;
}

/// What needs attention on [today]: return deadlines, warranties ending soon, and guests due to leave.
/// Built only from records already on the device.
List<AttentionItem> attentionItems({
  required List<Purchase> purchases,
  required PropertyBook book,
  required DateTime today,
  int returnWindowDays = 7,
  int warrantyWindowDays = 60,
  int leavingWindowDays = 7,
}) {
  final day = DateTime(today.year, today.month, today.day);
  final items = <AttentionItem>[];
  for (final p in purchases) {
    final ret = p.returnBy;
    if (ret != null && !ret.isBefore(day)) {
      final left = ret.difference(day).inDays;
      if (left <= returnWindowDays) {
        items.add(
          AttentionItem(
            title: left == 0
                ? 'Return today: ${p.name}'
                : 'Return ${p.name} by ${dayShort(ret)}',
            detail: 'Return window ends in $left ${left == 1 ? 'day' : 'days'}',
            route: '/purchases',
            urgent: true,
          ),
        );
      }
    }
    final warranty = p.warrantyUntil;
    if (warranty != null && !warranty.isBefore(day)) {
      final left = warranty.difference(day).inDays;
      if (left <= warrantyWindowDays) {
        items.add(
          AttentionItem(
            title: 'Warranty on ${p.name} ends ${dayShort(warranty)}',
            detail: 'In $left ${left == 1 ? 'day' : 'days'}',
            route: '/purchases',
            urgent: left <= 7,
          ),
        );
      }
    }
  }
  for (final t in book.tenancies) {
    final out = t.expectedCheckout;
    if (out == null || !t.isActiveOn(day)) continue;
    final left = out.difference(day).inDays;
    if (left >= 0 && left <= leavingWindowDays) {
      items.add(
        AttentionItem(
          title:
              '${t.name} leaves ${left == 0 ? 'today' : 'in $left ${left == 1 ? 'day' : 'days'}'}',
          detail: 'Check out, or extend the stay',
          route: '/person/${t.personId}',
          urgent: left <= 1,
        ),
      );
    }
  }
  items.sort((a, b) {
    if (a.urgent != b.urgent) return a.urgent ? -1 : 1;
    return a.title.compareTo(b.title);
  });
  return items;
}

/// Attention items for reminders that are overdue, due today, or due in the next few days.
List<AttentionItem> reminderAttentionItems(
  List<Reminder> reminders,
  DateTime now,
) {
  return [
    for (final r in remindersNeedingAttention(reminders, now))
      AttentionItem(
        title: r.title,
        detail: r.isOverdue(now)
            ? 'Overdue, was due ${dayShort(r.dueAt)}'
            : 'Due ${dayShort(r.dueAt)}',
        route: r.route.isEmpty ? '/reminders' : r.route,
        urgent: r.isDueToday(now),
      ),
  ];
}
