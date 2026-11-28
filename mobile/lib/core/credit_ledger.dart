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
  const CreditPayment({
    required this.id,
    required this.date,
    required this.cents,
    required this.note,
  });

  final String id;
  final DateTime date;
  final int cents;
  final String note;

  CreditPayment copyWith({String? note}) =>
      CreditPayment(id: id, date: date, cents: cents, note: note ?? this.note);

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': _isoDate(date),
    'cents': cents,
    'note': note,
  };

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
    this.iOwe = false,
    this.interestMethod = perBillInterest,
  });

  /// How interest is worked out: each bill by its days open, or once on the whole bill.
  static const perBillInterest = 'perBill';
  static const wholeBillInterest = 'wholeBill';
  static const atBillDatesInterest = 'atBillDates';
  final String interestMethod;

  final String id;
  final String name;
  final String phone;

  /// False: this person owes me (a customer, or money I lent). True: I owe them (a vendor, or money I borrowed).
  final bool iOwe;

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
    bool? iOwe,
    String? interestMethod,
    List<CreditBill>? bills,
    List<CreditPayment>? payments,
  }) => CreditAccount(
    id: id,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    annualRatePercent: annualRatePercent ?? this.annualRatePercent,
    compound: compound ?? this.compound,
    iOwe: iOwe ?? this.iOwe,
    interestMethod: interestMethod ?? this.interestMethod,
    bills: bills ?? this.bills,
    payments: payments ?? this.payments,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'annualRatePercent': annualRatePercent,
    'compound': compound,
    'iOwe': iOwe,
    'interestMethod': interestMethod,
    'bills': bills.map((b) => b.toJson()).toList(),
    'payments': payments.map((p) => p.toJson()).toList(),
  };

  factory CreditAccount.fromJson(Map<String, dynamic> j) => CreditAccount(
    id: '${j['id']}',
    name: '${j['name'] ?? ''}',
    phone: '${j['phone'] ?? ''}',
    annualRatePercent: (j['annualRatePercent'] as num?)?.toDouble() ?? 0,
    compound: j['compound'] == true,
    iOwe: j['iOwe'] == true,
    interestMethod: '${j['interestMethod'] ?? perBillInterest}',
    bills: [
      for (final b in (j['bills'] as List<dynamic>? ?? const []))
        CreditBill.fromJson(Map<String, dynamic>.from(b as Map)),
    ],
    payments: [
      for (final p in (j['payments'] as List<dynamic>? ?? const []))
        CreditPayment.fromJson(Map<String, dynamic>.from(p as Map)),
    ],
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
      asOf: end,
      principalCents: 0,
      interestCents: 0,
      lines: const [],
      days: const [],
      interestByMonth: const {},
      totalBilledCents: 0,
      totalPaidCents: 0,
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
        lines.add(
          StatementLine(
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
          ),
        );
      }
      for (final e in todaysPayments) {
        var left = e.cents.toDouble();
        final toInterest = left < interest ? left : interest;
        interestPaid[e.id] = toInterest.round();
        interest -= toInterest;
        left -= toInterest;
        principal -= left;
        paid += e.cents;
        lines.add(
          StatementLine(
            date: day,
            description: e.note.isEmpty
                ? 'Payment received'
                : 'Payment: ${e.note}',
            debitCents: 0,
            creditCents: e.cents,
            balanceCents: 0,
            refId: e.id,
            isPayment: true,
            notes: e.note,
          ),
        );
      }
      days.add(
        DayRow(
          date: day,
          bills: todaysBills,
          payments: todaysPayments,
          interestCents: interestSincePrevious.round(),
          balanceCents: (principal + interest).round(),
        ),
      );
      lastRowDay = day;
    }

    // Interest for this day, on what is owed at the end of the day before the next events.
    if (day.isBefore(end)) {
      // Simple interest only: interest is worked out on the amount owed, never on earlier interest.
      final base = principal;
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
    days.add(
      DayRow(
        date: end,
        bills: const [],
        payments: const [],
        interestCents: accruedSinceRow.round(),
        balanceCents: (principal + interest).round(),
      ),
    );
  }

  final monthTotals = <String, int>{
    for (final e in byMonth.entries) e.key: e.value.round(),
  };

  // Running balance, in date order.
  var running = 0;
  final ordered = [...lines]..sort((a, b) => a.date.compareTo(b.date));
  final withBalance = <StatementLine>[];
  for (final line in ordered) {
    running += line.debitCents - line.creditCents;
    withBalance.add(
      StatementLine(
        date: line.date,
        description: line.description,
        debitCents: line.debitCents,
        creditCents: line.creditCents,
        balanceCents: running,
        refId: line.refId,
        isPayment: line.isPayment,
        notes: line.notes,
      ),
    );
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

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class CreditLedgerStore {
  CreditLedgerStore._();

  static Future<List<CreditAccount>> load() async {
    final store = await LocalStore.open();
    final accounts = [
      for (final m in store.readList(ledgerKey)) CreditAccount.fromJson(m),
    ];
    accounts.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
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
      out.add(
        MoneyEntry(
          id: 'cint-${a.id}-${p.id}',
          income: true,
          title: 'Interest from ${a.name}',
          category: 'Interest received',
          cents: cents,
          date: p.date,
          notes: 'Part of a payment that cleared interest',
        ),
      );
    }
  }
  return out;
}

/// Keeps the credit interest entries in Monova Finance in step with the accounts.
Future<void> syncCreditInterest(List<CreditAccount> accounts) async {
  final entries = await EntryStore.loadEntries();
  final kept = [
    for (final e in entries)
      if (!e.id.startsWith('cint-')) e,
  ];
  await EntryStore.saveEntries([...kept, ...creditInterestEntries(accounts)]);
}

/// One bill's own history: when it was added, how long it has been open, what is still unpaid, and the simple
/// interest it has earned so far. Each bill earns interest from its own date, on what is still open.
class BillBreakdown {
  const BillBreakdown({
    required this.bill,
    required this.daysOpen,
    required this.openCents,
    required this.paidCents,
    required this.interestCents,
    required this.closedOn,
  });

  final CreditBill bill;
  final int daysOpen;

  /// Unpaid amount of this bill as of the date shown.
  final int openCents;

  /// Amount of this bill paid off so far (not counting interest).
  final int paidCents;

  /// Simple interest this bill has earned so far.
  final int interestCents;

  /// The date the bill was fully paid off, or null while it is still open.
  final DateTime? closedOn;
}

/// Works out each bill's own interest. Payments clear the account's accrued interest first (as in [computeStatement]),
/// and the rest pays off the oldest open bill first. Totals match the statement, because the same money is outstanding each day.
List<BillBreakdown> billBreakdowns(
  CreditAccount account,
  DateTime asOf,
  LedgerStatement statement,
) {
  final end = dateOnly(asOf);
  final dailyRate = account.annualRatePercent / 100 / 365;
  final bills = [...account.bills]..sort((a, b) => a.date.compareTo(b.date));
  final payments = [...account.payments]
    ..sort((a, b) => a.date.compareTo(b.date));
  final open = <String, double>{
    for (final b in bills) b.id: b.finalCents.toDouble(),
  };
  final interest = <String, double>{for (final b in bills) b.id: 0};
  final closedOn = <String, DateTime>{};

  if (bills.isNotEmpty) {
    var day = dateOnly(bills.first.date);
    var pi = 0;
    while (!day.isAfter(end)) {
      // Payments on this day pay the oldest open bill that already exists today.
      while (pi < payments.length && dateOnly(payments[pi].date) == day) {
        final p = payments[pi++];
        var left =
            p.cents.toDouble() - (statement.interestPaidByPayment[p.id] ?? 0);
        for (final b in bills) {
          if (left <= 0) break;
          if (dateOnly(b.date).isAfter(day) || open[b.id]! <= 0) continue;
          final take = left < open[b.id]! ? left : open[b.id]!;
          open[b.id] = open[b.id]! - take;
          left -= take;
          if (open[b.id]! <= 0.0001 && !closedOn.containsKey(b.id))
            closedOn[b.id] = day;
        }
      }
      // One day of simple interest on what each open bill still owes.
      if (day.isBefore(end)) {
        for (final b in bills) {
          if (dateOnly(b.date).isAfter(day) || open[b.id]! <= 0) continue;
          interest[b.id] = interest[b.id]! + open[b.id]! * dailyRate;
        }
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
  }

  return [
    for (final b in bills)
      BillBreakdown(
        bill: b,
        daysOpen: (closedOn[b.id] ?? end).difference(dateOnly(b.date)).inDays,
        openCents: open[b.id]!.round(),
        paidCents: (b.finalCents - open[b.id]!).round(),
        interestCents: interest[b.id]!.round(),
        closedOn: closedOn[b.id],
      ),
  ];
}

/// Whole-bill settlement. Each bill's interest is worked out once, on its full amount, for the days from the bill date
/// to [asOf]. Payments clear each bill's interest first, then its amount, oldest bill first. Here [BillBreakdown.openCents]
/// is what is still owed on the bill (amount plus interest left), and [BillBreakdown.interestCents] is the whole-bill interest.
List<BillBreakdown> wholeBillBreakdowns(CreditAccount account, DateTime asOf) {
  final end = dateOnly(asOf);
  final rate = account.annualRatePercent / 100 / 365;
  final bills = [...account.bills]..sort((a, b) => a.date.compareTo(b.date));
  final payments = [...account.payments]
    ..sort((a, b) => a.date.compareTo(b.date));
  final amountLeft = <String, int>{for (final b in bills) b.id: b.finalCents};
  final interestDue = <String, int>{};
  final interestLeft = <String, int>{};
  final daysOpen = <String, int>{};
  final paidTotal = <String, int>{for (final b in bills) b.id: 0};
  final closedOn = <String, DateTime>{};

  for (final b in bills) {
    final days = end.difference(dateOnly(b.date)).inDays;
    final days0 = days < 0 ? 0 : days;
    daysOpen[b.id] = days0;
    interestDue[b.id] = (b.finalCents * rate * days0).round();
    interestLeft[b.id] = interestDue[b.id]!;
  }

  for (final p in payments) {
    if (dateOnly(p.date).isAfter(end)) continue;
    var left = p.cents;
    for (final b in bills) {
      if (left <= 0) break;
      if (dateOnly(b.date).isAfter(dateOnly(p.date))) continue;
      final toInterest = left < interestLeft[b.id]!
          ? left
          : interestLeft[b.id]!;
      interestLeft[b.id] = interestLeft[b.id]! - toInterest;
      left -= toInterest;
      final toAmount = left < amountLeft[b.id]! ? left : amountLeft[b.id]!;
      amountLeft[b.id] = amountLeft[b.id]! - toAmount;
      paidTotal[b.id] = paidTotal[b.id]! + toInterest + toAmount;
      left -= toAmount;
      if (amountLeft[b.id]! == 0 &&
          interestLeft[b.id]! == 0 &&
          !closedOn.containsKey(b.id)) {
        closedOn[b.id] = dateOnly(p.date);
      }
    }
  }

  return [
    for (final b in bills)
      BillBreakdown(
        bill: b,
        daysOpen: daysOpen[b.id]!,
        openCents: amountLeft[b.id]! + interestLeft[b.id]!,
        paidCents: paidTotal[b.id]!,
        interestCents: interestDue[b.id]!,
        closedOn: closedOn[b.id],
      ),
  ];
}

/// Total still owed on an account today, under whichever interest method it uses.
int accountTotalCents(CreditAccount account, DateTime asOf) {
  if (account.interestMethod == CreditAccount.wholeBillInterest) {
    return wholeBillBreakdowns(
      account,
      asOf,
    ).fold<int>(0, (sum, b) => sum + b.openCents);
  }
  if (account.interestMethod == CreditAccount.atBillDatesInterest) {
    final steps = billDateSettlement(account, asOf);
    return steps.isEmpty ? 0 : steps.last.balanceCents;
  }
  return computeStatement(account, asOf).totalCents;
}

/// One step in a bill-date settlement: a bill, a payment, or interest added up to that date.
class SettlementStep {
  const SettlementStep({
    required this.date,
    required this.label,
    required this.amountCents,
    required this.interestCents,
    required this.balanceCents,
  });

  final DateTime date;
  final String label;

  /// Bill amount (positive), or payment amount (negative). Zero for interest-only steps.
  final int amountCents;

  /// Interest added at this step (positive), or interest cleared by a payment (negative).
  final int interestCents;

  /// Total owed after this step (principal plus interest).
  final int balanceCents;
}

/// Bill-date settlement. Interest runs from one bill date to the next. At each new bill, payment or settlement date,
/// the interest for the period is added to the balance, so the next period earns interest on it too.
/// A payment clears the interest added so far first, then the amount owed.
List<SettlementStep> billDateSettlement(CreditAccount account, DateTime asOf) {
  final end = dateOnly(asOf);
  final rate = account.annualRatePercent / 100 / 365;
  final events =
      <({DateTime date, int order, Object item})>[
        for (final b in account.bills)
          if (!dateOnly(b.date).isAfter(end))
            (date: dateOnly(b.date), order: 0, item: b),
        for (final p in account.payments)
          if (!dateOnly(p.date).isAfter(end))
            (date: dateOnly(p.date), order: 1, item: p),
      ]..sort((a, b) {
        final d = a.date.compareTo(b.date);
        return d != 0 ? d : a.order.compareTo(b.order);
      });

  var principal = 0.0;
  var interest = 0.0;
  DateTime? last;
  final steps = <SettlementStep>[];

  void accrueTo(DateTime d, String label) {
    if (last == null) return;
    final days = d.difference(last!).inDays;
    final base = principal + interest;
    if (days <= 0 || base <= 0) return;
    final accrued = base * rate * days;
    interest += accrued;
    steps.add(
      SettlementStep(
        date: d,
        label: label,
        amountCents: 0,
        interestCents: accrued.round(),
        balanceCents: (principal + interest).round(),
      ),
    );
  }

  for (final e in events) {
    accrueTo(
      e.date,
      'Interest from ${last == null ? '' : _shortDate(last!)} to ${_shortDate(e.date)}',
    );
    last = e.date;
    final item = e.item;
    if (item is CreditBill) {
      principal += item.finalCents;
      steps.add(
        SettlementStep(
          date: e.date,
          label:
              'Bill: ${item.billerName.isEmpty ? item.description : item.billerName}',
          amountCents: item.finalCents,
          interestCents: 0,
          balanceCents: (principal + interest).round(),
        ),
      );
    } else if (item is CreditPayment) {
      final cents = item.cents.toDouble();
      final toInterest = cents < interest ? cents : interest;
      interest -= toInterest;
      principal -= cents - toInterest;
      steps.add(
        SettlementStep(
          date: e.date,
          label: item.note.isEmpty
              ? 'Payment received'
              : 'Payment: ${item.note}',
          amountCents: -item.cents,
          interestCents: -toInterest.round(),
          balanceCents: (principal + interest).round(),
        ),
      );
    }
  }
  accrueTo(end, 'Interest to settlement date');
  return steps;
}

String _shortDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
