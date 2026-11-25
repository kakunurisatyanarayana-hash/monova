import 'local_store.dart';

const ledgerKey = 'monova.ledger';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// A bill given on credit: the date, the person it was given to (the biller), what it was for,
/// the amount before any discount and the final price that is owed.
class CreditBill {
  const CreditBill({
    required this.id,
    required this.date,
    required this.billerName,
    required this.description,
    required this.amountCents,
    required this.finalCents,
  });

  final String id;
  final DateTime date;
  final String billerName;
  final String description;
  final int amountCents;
  final int finalCents;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': _isoDate(date),
        'billerName': billerName,
        'description': description,
        'amountCents': amountCents,
        'finalCents': finalCents,
      };

  factory CreditBill.fromJson(Map<String, dynamic> j) => CreditBill(
        id: '${j['id']}',
        date: dateOnly(DateTime.parse('${j['date']}')),
        billerName: '${j['billerName'] ?? ''}',
        description: '${j['description'] ?? ''}',
        amountCents: (j['amountCents'] as num).toInt(),
        finalCents: (j['finalCents'] as num).toInt(),
      );
}

/// Money the customer paid back. Payments reduce the accrued interest first, then the amount owed.
class CreditPayment {
  const CreditPayment({required this.id, required this.date, required this.cents, required this.note});

  final String id;
  final DateTime date;
  final int cents;
  final String note;

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

/// One line of the statement: a bill, a payment, or the interest for a month.
class StatementLine {
  const StatementLine({
    required this.date,
    required this.description,
    required this.debitCents,
    required this.creditCents,
    required this.balanceCents,
    this.isInterest = false,
  });

  final DateTime date;
  final String description;

  /// Money added to the balance (bills and interest).
  final int debitCents;

  /// Money taken off the balance (payments).
  final int creditCents;

  /// Total owed (principal plus interest) after this line.
  final int balanceCents;
  final bool isInterest;
}

/// The result of working out what is owed on a given day.
class LedgerStatement {
  const LedgerStatement({
    required this.asOf,
    required this.principalCents,
    required this.interestCents,
    required this.lines,
    required this.interestByMonth,
    required this.totalBilledCents,
    required this.totalPaidCents,
  });

  final DateTime asOf;

  /// Money from bills that has not been paid back yet. It can be negative if the customer paid in advance.
  final int principalCents;

  /// Interest accrued and not yet paid.
  final int interestCents;
  final List<StatementLine> lines;

  /// Interest per calendar month (key "yyyy-mm"), in cents.
  final Map<String, int> interestByMonth;
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
  final lines = <StatementLine>[];
  if (events.isEmpty) {
    return LedgerStatement(
      asOf: end, principalCents: 0, interestCents: 0, lines: const [], interestByMonth: const {},
      totalBilledCents: 0, totalPaidCents: 0,
    );
  }

  final start = events.keys.reduce((a, b) => a.isBefore(b) ? a : b);
  final dailyRate = account.annualRatePercent / 100 / 365;
  var principal = 0.0;
  var interest = 0.0;
  var billed = 0;
  var paid = 0;
  final byMonth = <String, double>{};
  final monthTotals = <String, int>{};

  var day = start;
  while (!day.isAfter(end)) {
    final todays = events[day];
    if (todays != null) {
      // Bills first, then payments, in the order they were entered.
      for (final e in todays.whereType<CreditBill>()) {
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
        ));
      }
      for (final e in todays.whereType<CreditPayment>()) {
        var left = e.cents.toDouble();
        final toInterest = left < interest ? left : interest;
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
        ));
      }
    }

    // Interest for this day, on what is owed at the end of the day before the next events.
    if (day.isBefore(end)) {
      final base = account.compound ? principal + interest : principal;
      final accrual = base > 0 ? base * dailyRate : 0.0;
      interest += accrual;
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}';
      byMonth[key] = (byMonth[key] ?? 0) + accrual;
    }
    // Step by calendar day, so a daylight-saving change cannot skip or repeat a day.
    day = DateTime(day.year, day.month, day.day + 1);
  }

  // Interest by month, as whole rupees-and-paisa for display.
  for (final entry in byMonth.entries) {
    monthTotals[entry.key] = entry.value.round();
  }
  // Running balance, in the order the lines were added.
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
    ));
  }

  return LedgerStatement(
    asOf: end,
    principalCents: principal.round(),
    interestCents: interest.round(),
    lines: withBalance,
    interestByMonth: monthTotals,
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
  }
}
