// How interest is quoted, and the conversions the calculators use. Pure Dart, no network.
/// The ways people quote interest. The calculators work in a yearly percentage, so each way is converted to that.
enum RateUnit { percentYear, percentMonth, rupeesPer100Month, rupeesPer1000Month }

extension RateUnitText on RateUnit {
  String get label => switch (this) {
        RateUnit.percentYear => '% a year (like a bank)',
        RateUnit.percentMonth => '% a month',
        RateUnit.rupeesPer100Month => '₹ for every ₹100, a month',
        RateUnit.rupeesPer1000Month => '₹ for every ₹1,000, a month',
      };

  String get fieldLabel => switch (this) {
        RateUnit.percentYear => 'Interest % a year',
        RateUnit.percentMonth => 'Interest % a month',
        RateUnit.rupeesPer100Month => 'Interest ₹ per ₹100 a month',
        RateUnit.rupeesPer1000Month => 'Interest ₹ per ₹1,000 a month',
      };
}

/// Converts the number the person typed, in their own unit, into a yearly percentage.
/// Example: ₹2 for every ₹100 a month is 2% a month, which is 24% a year.
double toAnnualPercent(double value, RateUnit unit) => switch (unit) {
      RateUnit.percentYear => value,
      RateUnit.percentMonth => value * 12,
      RateUnit.rupeesPer100Month => value * 12,
      RateUnit.rupeesPer1000Month => value / 10 * 12,
    };

/// The values the scroll picker offers for each unit: from [min] to [max] in steps of [step], in the unit's own terms.
/// The step is fine enough for precise rates; the typed field still accepts any value.
class RateRange {
  const RateRange(this.min, this.max, this.step);

  final double min;
  final double max;
  final double step;

  int get count => ((max - min) / step).round() + 1;

  /// The value at position [index], rounded to two decimals so the wheel never shows float noise.
  double valueAt(int index) => double.parse((min + index * step).toStringAsFixed(2));

  /// The position closest to [value], clamped to the range.
  int indexOf(double value) {
    final i = ((value - min) / step).round();
    return i < 0 ? 0 : (i >= count ? count - 1 : i);
  }
}

RateRange rateRange(RateUnit unit) => switch (unit) {
      RateUnit.percentYear => const RateRange(0, 60, 0.05),
      RateUnit.percentMonth => const RateRange(0, 5, 0.01),
      RateUnit.rupeesPer100Month => const RateRange(0, 10, 0.05),
      RateUnit.rupeesPer1000Month => const RateRange(0, 100, 0.5),
    };

/// A rate written without trailing zeros: 2.50 becomes "2.5", 12.00 becomes "12".
String plainRate(double value) {
  final fixed = value.toStringAsFixed(2);
  return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
}

/// The same rate in the ways villagers quote it, with what it costs on ₹10,000.
String plainRateExplanation(double annualPercent) {
  final monthly = annualPercent / 12;
  final on10000 = 10000 * monthly / 100;
  return 'Pay ₹${monthly.toStringAsFixed(2)} for every ₹100 each month, '
      'or ₹${(monthly * 10).toStringAsFixed(0)} for every ₹1,000. '
      'On ₹10,000 that is ₹${on10000.toStringAsFixed(0)} a month, which is ${annualPercent.toStringAsFixed(1)}% a year.';
}

