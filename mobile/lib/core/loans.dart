import 'entry_store.dart';
import 'finance_calc.dart';
import 'local_store.dart';
import 'reminders.dart' show addMonths;

const loansKey = 'monova.loans';

/// Finance entries made by this module start with these prefixes, so they can be kept in step with the loan records.
const loanInPrefix = 'loanin-';
const loanPayPrefix = 'loanpay-';

/// 'emi': a loan repaid in equal monthly instalments (bank, finance company, a person).
/// 'open': money borrowed from someone, repaid in amounts of your choosing.
const loanKinds = <String>['emi', 'open'];

class LoanPayment {
  const LoanPayment({required this.id, required this.date, required this.cents, this.note = ''});

  final String id;
  final DateTime date;
  final int cents;
  final String note;

  Map<String, dynamic> toJson() => {'id': id, 'date': _day(date), 'cents': cents, 'note': note};

  factory LoanPayment.fromJson(Map<String, dynamic> j) => LoanPayment(
        id: '${j['id']}',
        date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
        cents: (j['cents'] as num?)?.toInt() ?? 0,
        note: '${j['note'] ?? ''}',
      );
}

String _day(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class Loan {
  const Loan({
    required this.id,
    required this.name,
    required this.kind,
    required this.principalCents,
    required this.startDate,
    this.annualRatePercent = 0,
    this.months = 0,
    this.payments = const [],
    this.notes = '',
  });

  final String id;

  /// Who the loan is from, for example "HDFC Bank" or "Ravi".
  final String name;
  final String kind;
  final int principalCents;
  final DateTime startDate;
  final double annualRatePercent;

  /// Number of monthly instalments (EMI loans only).
  final int months;
  final List<LoanPayment> payments;
  final String notes;

  bool get isEmi => kind == 'emi';

  int get paidCents => payments.fold(0, (sum, p) => sum + p.cents);

  /// The monthly instalment, in paise, for an EMI loan. Zero for open loans.
  int get emiCents {
    if (!isEmi || months <= 0) return 0;
    final emi = FinanceCalc.emi(principal: principalCents / 100, annualRatePercent: annualRatePercent, months: months).emi;
    return (emi * 100).round();
  }

  /// Instalments whose due date has come by [today].
  int dueInstallments(DateTime today) {
    if (!isEmi || months <= 0) return 0;
    var count = 0;
    final day = DateTime(today.year, today.month, today.day);
    for (var k = 1; k <= months; k++) {
      if (!addMonths(startDate, k).isAfter(day)) count++;
    }
    return count;
  }

  /// The date of the next instalment that is not yet paid, or null when the loan is finished.
  DateTime? nextDueDate() {
    if (!isEmi) return null;
    if (payments.length >= months) return null;
    return addMonths(startDate, payments.length + 1);
  }

  /// Instalments that are due but not paid.
  int overdueInstallments(DateTime today) {
    final late = dueInstallments(today) - payments.length;
    return late < 0 ? 0 : late;
  }

  /// What is still owed, in paise.
  int outstandingCents() {
    if (!isEmi) {
      final left = principalCents - paidCents;
      return left < 0 ? 0 : left;
    }
    // Balance after k instalments of the standard amortising schedule.
    final k = payments.length;
    if (k >= months) return 0;
    final r = annualRatePercent / 12 / 100;
    final p = principalCents / 100;
    final emi = emiCents / 100;
    final balance = r == 0 ? p - emi * k : p * _pow(1 + r, k) - emi * (_pow(1 + r, k) - 1) / r;
    final cents = (balance * 100).round();
    return cents < 0 ? 0 : cents;
  }

  /// Share repaid, from 0 to 1.
  double get progress {
    if (principalCents <= 0) return 0;
    if (isEmi) return (payments.length / (months <= 0 ? 1 : months)).clamp(0.0, 1.0);
    return (paidCents / principalCents).clamp(0.0, 1.0);
  }

  bool get finished => outstandingCents() == 0;

  Loan withPayment(LoanPayment p) => _copy(payments: [...payments, p]);

  Loan withoutPayment(String paymentId) => _copy(payments: [for (final p in payments) if (p.id != paymentId) p]);

  Loan _copy({List<LoanPayment>? payments, String? name, int? principalCents, DateTime? startDate, double? annualRatePercent, int? months, String? notes}) => Loan(
        id: id,
        name: name ?? this.name,
        kind: kind,
        principalCents: principalCents ?? this.principalCents,
        startDate: startDate ?? this.startDate,
        annualRatePercent: annualRatePercent ?? this.annualRatePercent,
        months: months ?? this.months,
        payments: payments ?? this.payments,
        notes: notes ?? this.notes,
      );

  Loan edited({String? name, int? principalCents, DateTime? startDate, double? annualRatePercent, int? months, String? notes}) =>
      _copy(name: name, principalCents: principalCents, startDate: startDate, annualRatePercent: annualRatePercent, months: months, notes: notes);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'principalCents': principalCents,
        'startDate': _day(startDate),
        'annualRatePercent': annualRatePercent,
        'months': months,
        'payments': [for (final p in payments) p.toJson()],
        'notes': notes,
      };

  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}',
        kind: loanKinds.contains(j['kind']) ? '${j['kind']}' : 'open',
        principalCents: (j['principalCents'] as num?)?.toInt() ?? 0,
        startDate: DateTime.tryParse('${j['startDate']}') ?? DateTime.now(),
        annualRatePercent: (j['annualRatePercent'] as num?)?.toDouble() ?? 0,
        months: (j['months'] as num?)?.toInt() ?? 0,
        payments: [for (final p in (j['payments'] as List<dynamic>? ?? const [])) LoanPayment.fromJson(Map<String, dynamic>.from(p as Map))],
        notes: '${j['notes'] ?? ''}',
      );
}

double _pow(double base, int exp) {
  var result = 1.0;
  for (var i = 0; i < exp; i++) {
    result *= base;
  }
  return result;
}

/// The finance entries that mirror the loans: money received when a loan starts, and every repayment as spending.
List<MoneyEntry> loanFinanceEntries(List<Loan> loans) {
  final out = <MoneyEntry>[];
  for (final l in loans) {
    out.add(MoneyEntry(
      id: '$loanInPrefix${l.id}',
      income: true,
      title: 'Borrowed from ${l.name}',
      category: 'Loan received',
      cents: l.principalCents,
      date: l.startDate,
      notes: l.isEmi ? '${l.months} monthly instalments' : '',
    ));
    for (final p in l.payments) {
      out.add(MoneyEntry(
        id: '$loanPayPrefix${p.id}',
        income: false,
        title: 'Repaid ${l.name}',
        category: 'Loan repayment',
        cents: p.cents,
        date: p.date,
        notes: p.note,
      ));
    }
  }
  return out;
}

/// Brings the loan entries in [entries] in line with [loans]: adds missing ones, updates changed ones,
/// and removes entries whose loan or repayment was deleted. Other entries are left alone.
List<MoneyEntry> mergeLoanEntries(List<MoneyEntry> entries, List<Loan> loans) {
  final wanted = {for (final e in loanFinanceEntries(loans)) e.id: e};
  final kept = <MoneyEntry>[
    for (final e in entries)
      if (!(e.id.startsWith(loanInPrefix) || e.id.startsWith(loanPayPrefix))) e else if (wanted.containsKey(e.id)) wanted[e.id]!,
  ];
  final existing = {for (final e in entries) e.id};
  return [...kept, for (final e in wanted.values) if (!existing.contains(e.id)) e];
}

class LoanStore {
  LoanStore._();

  static Future<List<Loan>> load() async {
    final store = await LocalStore.open();
    return [for (final m in store.readList(loansKey)) Loan.fromJson(m)];
  }

  /// Saves the loans and keeps Monova Finance in step with them.
  static Future<void> save(List<Loan> loans) async {
    final store = await LocalStore.open();
    await store.writeList(loansKey, [for (final l in loans) l.toJson()]);
    final entries = await EntryStore.loadEntries();
    await EntryStore.saveEntries(mergeLoanEntries(entries, loans));
  }
}
