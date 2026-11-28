import 'attention.dart';
import 'format.dart';
import 'property_store.dart';

/// Add [months] to [d], keeping the same day of the month where the month has it (27 Nov + 1 = 27 Dec; 31 Jan + 1 = 28 Feb).
DateTime addRentMonths(DateTime d, int months) {
  final total = d.month - 1 + months;
  final year = d.year + total ~/ 12;
  final month = total % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, d.day.clamp(1, lastDay).toInt());
}

/// Rent for one stay. The stay starts on the check-in date and runs in monthly cycles on that same day.
/// Money paid covers cycles from the start: each full monthly amount moves the paid-up date forward one month,
/// so paying two months in advance covers two cycles. Any part of a payment left over counts toward the next cycle.
class RentStatus {
  const RentStatus({
    required this.tenancy,
    required this.paidThrough,
    required this.totalPaidCents,
  });

  final Tenancy tenancy;

  /// Rent is paid for every day before this date. This is also the next due date.
  final DateTime paidThrough;

  /// Everything paid for this stay so far.
  final int totalPaidCents;

  int get amountCents => tenancy.rentCents;

  /// The date the next payment is due. Same day of the month as check-in.
  DateTime get dueOn => paidThrough;

  /// What is still unpaid for the cycle that starts on [dueOn].
  int get owedCents => amountCents - (totalPaidCents % amountCents);

  /// True when the next cycle is not yet due within the reminder window. The UI shows it as paid up.
  bool isPaidUpOn(DateTime today, {int windowDays = 3}) {
    final day = DateTime(today.year, today.month, today.day);
    return dueOn.difference(day).inDays > windowDays;
  }

  bool isOverdue(DateTime today) {
    final day = DateTime(today.year, today.month, today.day);
    return dueOn.isBefore(day);
  }
}

/// The rent status for [t] on [today], or null when the stay has no rent or is not active today.
RentStatus? rentStatusFor(PropertyBook book, Tenancy t, DateTime today) {
  final day = DateTime(today.year, today.month, today.day);
  if (t.rentCents <= 0 || !t.isActiveOn(day)) return null;
  var paid = 0;
  for (final p in book.payments) {
    if (p.tenancyId == t.id && p.kind == 'rent') paid += p.amountCents;
  }
  final covered = paid ~/ t.rentCents;
  final checkIn = DateTime(t.checkIn.year, t.checkIn.month, t.checkIn.day);
  return RentStatus(
    tenancy: t,
    paidThrough: addRentMonths(checkIn, covered),
    totalPaidCents: paid,
  );
}

/// Attention items for rent that is overdue or due within [windowDays] days.
List<AttentionItem> rentAttentionItems(
  PropertyBook book,
  DateTime today, {
  int windowDays = 3,
}) {
  final day = DateTime(today.year, today.month, today.day);
  final items = <AttentionItem>[];
  for (final t in book.tenancies) {
    final s = rentStatusFor(book, t, today);
    if (s == null || s.isPaidUpOn(today, windowDays: windowDays)) continue;
    final overdue = s.isOverdue(today);
    final dueToday = s.dueOn == day;
    items.add(
      AttentionItem(
        title: overdue
            ? 'Rent overdue: ${t.name}'
            : (dueToday
                  ? 'Rent due today: ${t.name}'
                  : 'Rent due ${dayShort(s.dueOn)}: ${t.name}'),
        detail: '${money(s.owedCents / 100)} due · tap to record or remind',
        route: t.personId.isEmpty
            ? '/property/${t.propertyId}'
            : '/person/${t.personId}',
        urgent: overdue || dueToday,
      ),
    );
  }
  return items;
}

enum RentDueKind { overdue, today, soon }

/// One tenant whose rent needs attention, with the room it is in.
class RentDueRow {
  const RentDueRow({
    required this.tenancy,
    required this.room,
    required this.status,
    required this.kind,
  });

  final Tenancy tenancy;
  final Room? room;
  final RentStatus status;
  final RentDueKind kind;
}

/// Every tenant whose rent is overdue, due today, or due within [windowDays] days.
List<RentDueRow> rentDueRows(
  PropertyBook book,
  DateTime today, {
  int windowDays = 3,
}) {
  final day = DateTime(today.year, today.month, today.day);
  final rows = <RentDueRow>[];
  for (final t in book.tenancies) {
    final s = rentStatusFor(book, t, today);
    if (s == null || s.isPaidUpOn(today, windowDays: windowDays)) continue;
    final kind = s.isOverdue(today)
        ? RentDueKind.overdue
        : (s.dueOn == day ? RentDueKind.today : RentDueKind.soon);
    rows.add(
      RentDueRow(
        tenancy: t,
        room: book.roomById(t.roomId),
        status: s,
        kind: kind,
      ),
    );
  }
  return rows;
}

/// Home summary: one line per status (overdue, due today, due soon), each opening the rent list.
List<AttentionItem> rentSummaryItems(
  PropertyBook book,
  DateTime today, {
  int windowDays = 3,
}) {
  final rows = rentDueRows(book, today, windowDays: windowDays);
  final items = <AttentionItem>[];
  void add(RentDueKind kind, String what, bool urgent) {
    final n = rows.where((r) => r.kind == kind).length;
    if (n == 0) return;
    items.add(
      AttentionItem(
        title: '$n ${n == 1 ? 'rent' : 'rents'} $what',
        detail: 'Tap to see them by property, floor and room',
        route: '/rent-due',
        urgent: urgent,
      ),
    );
  }

  add(RentDueKind.overdue, 'overdue', true);
  add(RentDueKind.today, 'due today', true);
  add(RentDueKind.soon, 'due in the next $windowDays days', false);
  return items;
}
