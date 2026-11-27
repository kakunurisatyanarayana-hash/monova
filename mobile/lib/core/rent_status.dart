import 'attention.dart';
import 'format.dart';
import 'property_store.dart';

/// Rent for one tenancy in one month: the amount, the due date, and how much has been paid.
/// The due date is the check-in day of the month (the tenancy has no separate due day).
class RentStatus {
  const RentStatus({
    required this.tenancy,
    required this.dueOn,
    required this.paidCents,
  });

  final Tenancy tenancy;
  final DateTime dueOn;
  final int paidCents;

  int get amountCents => tenancy.rentCents;
  int get owedCents => (amountCents - paidCents).clamp(0, amountCents).toInt();
  bool get isPaid => owedCents == 0;

  bool isOverdue(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    return !isPaid && dueOn.isBefore(day);
  }
}

/// The rent status for [t] in the month of [today], or null when the tenancy has no rent or is not active today.
RentStatus? rentStatusFor(PropertyBook book, Tenancy t, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  if (t.rentCents <= 0 || !t.isActiveOn(day)) return null;
  final lastDay = DateTime(today.year, today.month + 1, 0).day;
  final dueOn = DateTime(
    today.year,
    today.month,
    t.checkIn.day.clamp(1, lastDay).toInt(),
  );
  var paid = 0;
  for (final p in book.payments) {
    if (p.tenancyId != t.id || p.kind != 'rent') continue;
    if (p.date.year == today.year && p.date.month == today.month)
      paid += p.amountCents;
  }
  return RentStatus(tenancy: t, dueOn: dueOn, paidCents: paid);
}

/// Attention items for rent that is overdue or due within [windowDays] days and not yet paid.
List<AttentionItem> rentAttentionItems(
  PropertyBook book,
  DateTime today, {
  int windowDays = 3,
}) {
  final day = DateTime(today.year, today.month, today.day);
  final items = <AttentionItem>[];
  for (final t in book.tenancies) {
    final s = rentStatusFor(book, t, today);
    if (s == null || s.isPaid) continue;
    if (s.dueOn.difference(day).inDays > windowDays) continue;
    final overdue = s.isOverdue(today);
    final dueToday = s.dueOn == day;
    items.add(
      AttentionItem(
        title: overdue
            ? 'Rent overdue: ${t.name}'
            : (dueToday
                  ? 'Rent due today: ${t.name}'
                  : 'Rent due ${dayShort(s.dueOn)}: ${t.name}'),
        detail: '${money(s.owedCents / 100)} unpaid · tap to record or remind',
        route: t.personId.isEmpty
            ? '/property/${t.propertyId}'
            : '/person/${t.personId}',
        urgent: overdue || dueToday,
      ),
    );
  }
  return items;
}
