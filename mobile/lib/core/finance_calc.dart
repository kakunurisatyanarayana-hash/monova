import 'dart:math' as math;

/// Offline financial calculators. They run on the device, so they work without an account.
/// Results are for planning; the server's ledger remains the authority for stored money.

class EmiResult {
  const EmiResult({required this.emi, required this.totalPayable, required this.totalInterest});

  final double emi;
  final double totalPayable;
  final double totalInterest;
}

class FinanceCalc {
  FinanceCalc._();

  static double round2(double v) => (v * 100).roundToDouble() / 100;

  /// Reducing-balance EMI: P * r * (1+r)^n / ((1+r)^n - 1), r = annual rate / 12 / 100.
  static EmiResult emi({required double principal, required double annualRatePercent, required int months}) {
    if (principal <= 0 || months <= 0 || annualRatePercent < 0) {
      throw ArgumentError('Principal and months must be positive and the rate cannot be negative.');
    }
    double emi;
    if (annualRatePercent == 0) {
      emi = principal / months;
    } else {
      final r = annualRatePercent / 12 / 100;
      final growth = math.pow(1 + r, months).toDouble();
      emi = principal * r * growth / (growth - 1);
    }
    final payable = emi * months;
    return EmiResult(emi: round2(emi), totalPayable: round2(payable), totalInterest: round2(payable - principal));
  }

  /// Simple interest: P * r * t / 100, where t is in years.
  static double simpleInterest({required double principal, required double annualRatePercent, required double years}) =>
      round2(principal * annualRatePercent * years / 100);

  /// Compound interest with n compounding periods per year. Returns the final amount and the interest earned.
  static ({double amount, double interest}) compound({
    required double principal,
    required double annualRatePercent,
    required double years,
    int compoundsPerYear = 12,
  }) {
    final amount = principal * math.pow(1 + annualRatePercent / 100 / compoundsPerYear, compoundsPerYear * years);
    return (amount: round2(amount.toDouble()), interest: round2(amount.toDouble() - principal));
  }

  /// Splits an amount into whole paise so the shares always add up exactly.
  /// [mode] is one of: equal, exact, percent, shares. [values] is ignored for equal.
  /// Leftover paise go one each to the first participants in the list (deterministic).
  static List<int> splitCents({
    required int totalCents,
    required String mode,
    required List<double?> values,
  }) {
    final n = values.length;
    if (n == 0) throw ArgumentError('Add at least one person to split with.');
    if (totalCents <= 0) throw ArgumentError('Amount must be greater than zero.');

    switch (mode) {
      case 'equal':
        final base = totalCents ~/ n;
        final remainder = totalCents % n;
        return [for (var i = 0; i < n; i++) base + (i < remainder ? 1 : 0)];

      case 'exact':
        final cents = [for (final v in values) _toCents(v, 'Exact amount')];
        final sum = cents.fold<int>(0, (a, b) => a + b);
        if (sum != totalCents) {
          throw ArgumentError('Exact amounts add up to ${sum / 100}, but the total is ${totalCents / 100}.');
        }
        return cents;

      case 'percent':
        final basisPoints = [for (final v in values) _toScaled(v, 100, 'Percentage')];
        final sum = basisPoints.fold<int>(0, (a, b) => a + b);
        if (sum != 10000) throw ArgumentError('Percentages must add up to 100.');
        return _allocate(totalCents, basisPoints, 10000);

      case 'shares':
        final weights = [for (final v in values) _toScaled(v, 1000, 'Share')];
        final sum = weights.fold<int>(0, (a, b) => a + b);
        return _allocate(totalCents, weights, sum);

      default:
        throw ArgumentError('Unknown split mode: $mode');
    }
  }

  static int _toCents(double? v, String label) {
    if (v == null || v < 0) throw ArgumentError('$label must be zero or positive.');
    return (v * 100).round();
  }

  static int _toScaled(double? v, int scale, String label) {
    if (v == null || v <= 0) throw ArgumentError('$label must be greater than zero.');
    return (v * scale).round();
  }

  static List<int> _allocate(int totalCents, List<int> parts, int denominator) {
    final floors = [for (final p in parts) (totalCents * p) ~/ denominator];
    var remainder = totalCents - floors.fold<int>(0, (a, b) => a + b);
    final result = [...floors];
    for (var i = 0; i < result.length && remainder > 0; i++, remainder--) {
      result[i] += 1;
    }
    return result;
  }

  /// Turns each person's net position (positive = owed money) into the fewest practical payments.
  /// Net positions must add up to zero.
  static List<({String from, String to, int cents})> settle(Map<String, int> netCents) {
    final total = netCents.values.fold<int>(0, (a, b) => a + b);
    if (total != 0) throw ArgumentError('Balances must add up to zero.');

    final creditors = netCents.entries.where((e) => e.value > 0).map((e) => MapEntry(e.key, e.value)).toList()
      ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
    final debtors = netCents.entries.where((e) => e.value < 0).map((e) => MapEntry(e.key, -e.value)).toList()
      ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));

    final out = <({String from, String to, int cents})>[];
    var c = 0, d = 0;
    while (c < creditors.length && d < debtors.length) {
      final pay = math.min(creditors[c].value, debtors[d].value);
      out.add((from: debtors[d].key, to: creditors[c].key, cents: pay));
      creditors[c] = MapEntry(creditors[c].key, creditors[c].value - pay);
      debtors[d] = MapEntry(debtors[d].key, debtors[d].value - pay);
      if (creditors[c].value == 0) c++;
      if (debtors[d].value == 0) d++;
    }
    return out;
  }
}
