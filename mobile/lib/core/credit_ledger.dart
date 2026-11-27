import 'entry_store.dart';
import 'local_store.dart';

const ledgerKey = 'monova.ledger';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// A bill given on credit: the date, the person it was given to (the biller), what it was for,
/// the amount before any discount, the final price that is owed, and any notes kept with it.
class CreditBill {
  const CreditBill({
    required this.id,
    required this.date,
    required this.billerName,
    required this.description,
    required this.amountCents,
    required this.finalCents,
    this.notes = '',
  });

  final String id;
  final DateTime date;
  final String billerName;
  final String description;
  final int amountCents;
  final int finalCents;
  final String notes;

  CreditBill copyWith({String? notes}) => CreditBill(
        id: id,
        date: date,
        billerName: billerName,
        description: description,
        amountCents: amountCents,
        finalCents: finalCents,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': _isoDate(date),
        'billerName': billerName,
        'description': description,
        'amountCents': amountCents,
        'finalCents': finalCents,
        'notes': notes,
      };

  factory CreditBill.fromJson(Map<String, dynamic> j) => CreditBill(
        id: '${j['id']}',
        date: dateOnly(DateTime.parse('${j['date']}')),
        billerName: '${j['billerName'] ?? ''}',
        description: '${j['description'] ?? ''}',
        amountCents: (j['amountCents'] as num).toInt(),
        finalCents: (j['finalCents'] as num).toInt(),
        notes: '${j['notes'] ?? ''}',
      );
}

/// Money the customer paid back. Payments reduce the accrued interest first, then the amount owed.
class CreditPayment {
  const CreditPayment({required this.id, required this.date, required this.cents, required this.note});

  final String id;
  final DateTime date;
  final int cents;
  final String note;

  CreditPayment copyWith({String? note}) => CreditPayment(id: id, date: date, cents: cents, note: note ?? this.note);

  Map<String, dynamic> toJson() => {'id': id, 'date': _isoDate(date), 'cents': cents, 'note': note};

  factory CreditPayment.fromJson(Map<String, dynamic> j) => CreditPayment(
        id: '${j['id']}',
        date: dateOnly(DateTime.parse('${j['date']}')),
        cents: (j['cents'] as num).toInt(),
        note: '${j['note'] ?? ''}',
      );
}

/// One customer account with its interest terms.
class CreditAccount {
  const CreditAccount({
    required this.id,
    required this.name,
    required this.phone,
    required this.annualRatePercent,
    required this.compound,
    required this.bills,
    required this.payments,
  });

  final String id;
  final String name;
  final String phone;

  /// Yearly interest in percent. It is applied per day, on the outstanding amount (divided by 365).
  final double annualRatePercent;

  /// False: simple interest, on the amount owed only. True: interest is added to the balance, so it earns interest too.
  final bool compound;
  final List<CreditBill> bills;
  final List<CreditPayment> payments;

  CreditAccount copyWith({
    String? name,
    String? phone,
    double? annualRatePercent,
    bool? compound,
    List<CreditBill>? bills,
    List<CreditPayment>? payments,
  }) =>
      CreditAccount(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        annualRatePercent: annualRatePercent ?? this.annualRatePercent,
        compound: compound ?? this.compound,
        bills: bills ?? this.bills,
        payments: payments ?? this.payments,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'annualRatePercent': annualRatePercent,
        'compound': compound,
        'bills': bills.map((b) => b.toJson()).toList(),
        'payments': payments.map((p) => p.toJson()).toList(),
      };

  factory CreditAccount.fromJson(Map<String, dynamic> j) => CreditAccount(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        phone: '${j['phone'] ?? ''}',
        annualRatePercent: (j['annualRatePercent'] as num?)?.toDouble() ?? 0,
        compound: j['compound'] == true,
        bills: [for (final b in (j['bills'] as List<dynamic>? ?? const [])) CreditBill.fromJson(Map<String, dynamic>.from(b as Map))],
        payments: [for (final p in (j['payments'] as List<dynamic>? ?? const [])) CreditPayment.fromJson(Map<String, dynamic>.from(p as Map))],
      );
}

/// One line of the statement: a bill or a payment, with its id so it can be opened and edited.
class StatementLine {
  const StatementLine({
    required this.date,
    required this.description,
    required this.debitCents,
    required this.creditCents,
    required this.balanceCents,
    required this.refId,
    required this.isPayment,
    this.notes = '',
  });

  final DateTime date;
  final String description;

  /// Money added to the balance (a bill).
  final int debitCents;

  /// Money taken off the balance (a payment).
  final int creditCents;

  /// Total owed (principal plus interest) after this line.
  final int balanceCents;

  /// The id of the bill or payment this line came from.
  final String refId;
  final bool isPayment;
  final String notes;
}

/// Everything that happened on one day, with the interest since the previous entry and the balance after that day.
class DayRow {
  const DayRow({
    required this.date,
    required this.bills,
    required this.payments,
    required this.interestCents,
    required this.balanceCents,
  });

  final DateTime date;
  final List<CreditBill> bills;
  final List<CreditPayment> payments;

  /// Interest accrued since the previous row (the days in between), before any payment on this day.
  final int interestCents;

  /// Total owed (principal plus interest) at the end of this day.
  final int balanceCents;

  int get billedCents => bills.fold(0, (s, b) => s + b.finalCents);
  int get paidCents => payments.fold(0, (s, p) => s + p.cents);
}

/// The result of working out what is owed on a given day.
class LedgerStatement {
  const LedgerStatement({
    required this.asOf,
    required this.principalCents,
    required this.interestCents,
    required this.lines,
    required this.days,
    required this.interestByMonth,
    this.interestPaidByPayment = const {},
    required this.totalBilledCents,
    required this.totalPaidCents,
  });

  final DateTime asOf;

  /// Money from bills that has not been paid back yet. It can be negative if the customer paid in advance.
  final int principalCents;

  /// Interest accrued and not yet paid.
  final int interestCents;

  /// Every bill and payment, in date order, with the running balance.
  final List<StatementLine> lines;

  /// One row per day something happened, plus a final row up to [asOf] if interest has run since.
  final List<DayRow> days;

  /// Interest per calendar month (key "yyyy-mm"), in cents.
  final Map<String, int> interestByMonth;

  /// The part of each payment (by payment id) that cleared interest.
  final Map<String, int> interestPaidByPayment;
  final int totalBilledCents;
  final int totalPaidCents;

  /// Everything the customer owes on [asOf].
  int get totalCents => principalCents + interestCents;
}

/// Works out what is owed on [asOf].
///
/// Each day, the day's bills and payments are applied first. Then one day of interest is added to what is owed,
/// at the yearly rate divided by 365. A payment goes to the accrued interest first, and the rest reduces the amount owed.
/// Interest is kept at fractions of a paisa while the days add up, and rounded only for display.
LedgerStatement computeStatement(CreditAccount account, DateTime asOf) {
  final end = dateOnly(asOf);
  final events = <DateTime, List<Object>>{};
  for (final b in account.bills) {
    if (!b.date.isAfter(end)) events.putIfAbsent(b.date, () => []).add(b);
  }
  for (final p in account.payments) {
    if (!p.date.isAfter(end)) events.putIfAbsent(p.date, () => []).add(p);
  }
  if (events.isEmpty) {
    return LedgerStatement(
      asOf: end, principalCents: 0, interestCents: 0, lines: const [], days: const [], interestByMonth: const {},
      totalBilledCents: 0, totalPaidCents: 0,
    );
  }

  final start = events.keys.reduce((a, b) => a.isBefore(b) ? a : b);
  final dailyRate = account.annualRatePercent / 100 / 365;
  var principal = 0.0;
  var interest = 0.0;
  var billed = 0;
  var paid = 0;
  var accruedSinceRow = 0.0;
  final lines = <StatementLine>[];
  final days = <DayRow>[];
  final byMonth = <String, double>{};
  final interestPaid = <String, int>{};
  DateTime? lastRowDay;

  var day = start;
  while (!day.isAfter(end)) {
    final todays = events[day];
    if (todays != null) {
      final todaysBills = todays.whereType<CreditBill>().toList();
      final todaysPayments = todays.whereType<CreditPayment>().toList();
      // Interest that ran from the previous entry up to today, before today's events.
      final interestSincePrevious = accruedSinceRow;
      accruedSinceRow = 0;

      // Bills first, then payments, in the order they were entered.
      for (final e in todaysBills) {
        principal += e.finalCents;
        billed += e.finalCents;
        lines.add(StatementLine(
          date: day,
          description: e.billerName.isEmpty
              ? (e.description.isEmpty ? 'Bill' : e.description)
              : '${e.billerName}${e.description.isEmpty ? '' : ' - ${e.description}'}',
          debitCents: e.finalCents,
          creditCents: 0,
          balanceCents: 0,
          refId: e.id,
          isPayment: false,
          notes: e.notes,
        ));
      }
      for (final e in todaysPayments) {
        var left = e.cents.toDouble();
        final toInterest = left < interest ? left : interest;
        interestPaid[e.id] = toInterest.round();
        interest -= toInterest;
        left -= toInterest;
        principal -= left;
        paid += e.cents;
        lines.add(StatementLine(
          date: day,
          description: e.note.isEmpty ? 'Payment received' : 'Payment: ${e.note}',
          debitCents: 0,
          creditCents: e.cents,
          balanceCents: 0,
          refId: e.id,
          isPayment: true,
          notes: e.note,
        ));
      }
      days.add(DayRow(
        date: day,
        bills: todaysBills,
        payments: todaysPayments,
        interestCents: interestSincePrevious.round(),
        balanceCents: (principal + interest).round(),
      ));
      lastRowDay = day;
    }

    // Interest for this day, on what is owed at the end of the day before the next events.
    if (day.isBefore(end)) {
      final base = account.compound ? principal + interest : principal;
      final accrual = base > 0 ? base * dailyRate : 0.0;
      interest += accrual;
      accruedSinceRow += accrual;
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}';
      byMonth[key] = (byMonth[key] ?? 0) + accrual;
    }
    // Step by calendar day, so a daylight-saving change cannot skip or repeat a day.
    day = DateTime(day.year, day.month, day.day + 1);
  }

  // Interest has run since the last entry: show it on the as-of date.
  if (lastRowDay == null || lastRowDay.isBefore(end)) {
    days.add(DayRow(
      date: end,
      bills: const [],
      payments: const [],
      interestCents: accruedSinceRow.round(),
      balanceCents: (principal + interest).round(),
    ));
  }

  final monthTotals = <String, int>{for (final e in byMonth.entries) e.key: e.value.round()};

  // Running balance, in date order.
  var running = 0;
  final ordered = [...lines]..sort((a, b) => a.date.compareTo(b.date));
  final withBalance = <StatementLine>[];
  for (final line in ordered) {
    running += line.debitCents - line.creditCents;
    withBalance.add(StatementLine(
      date: line.date,
      description: line.description,
      debitCents: line.debitCents,
      creditCents: line.creditCents,
      balanceCents: running,
      refId: line.refId,
      isPayment: line.isPayment,
      notes: line.notes,
    ));
  }

  return LedgerStatement(
    asOf: end,
    principalCents: principal.round(),
    interestCents: interest.round(),
    lines: withBalance,
    days: days,
    interestByMonth: monthTotals,
    interestPaidByPayment: interestPaid,
    totalBilledCents: billed,
    totalPaidCents: paid,
  );
}

String _isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class CreditLedgerStore {
  CreditLedgerStore._();

  static Future<List<CreditAccount>> load() async {
    final store = await LocalStore.open();
    final accounts = [for (final m in store.readList(ledgerKey)) CreditAccount.fromJson(m)];
    accounts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return accounts;
  }

  static Future<void> save(List<CreditAccount> accounts) async {
    final store = await LocalStore.open();
    await store.writeList(ledgerKey, [for (final a in accounts) a.toJson()]);
    await syncCreditInterest(accounts);
  }
}

/// Interest received from customers, as income on the day it is paid. Each payment clears the interest owed first,
/// so the part that cleared interest is the interest received. The rest of a payment is the customer paying back what they owed, not income.
List<MoneyEntry> creditInterestEntries(List<CreditAccount> accounts) {
  final out = <MoneyEntry>[];
  for (final a in accounts) {
    final statement = computeStatement(a, DateTime.now());
    for (final p in a.payments) {
      final cents = statement.interestPaidByPayment[p.id] ?? 0;
      if (cents <= 0) continue;
      out.add(MoneyEntry(
        id: 'cint-${a.id}-${p.id}',
        income: true,
        title: 'Interest from ${a.name}',
        category: 'Interest received',
        cents: cents,
        date: p.date,
        notes: 'Part of a payment that cleared interest',
      ));
    }
  }
  return out;
}

/// Keeps the credit interest entries in Monova Finance in step with the accounts.
Future<void> syncCreditInterest(List<CreditAccount> accounts) async {
  final entries = await EntryStore.loadEntries();
  final kept = [for (final e in entries) if (!e.id.startsWith('cint-')) e];
  await EntryStore.saveEntries([...kept, ...creditInterestEntries(accounts)]);
}
