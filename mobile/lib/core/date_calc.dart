import 'dart:math' as math;

/// Calendar-based date maths: age, time between dates, and loan or rent terms in days, months or years.
/// Dates are compared by calendar day only (time of day is ignored).
class DateCalc {
  DateCalc._();

  static DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Adds calendar months. A day that doesn't exist in the target month is clamped to its last day (31 Jan + 1 month = 28/29 Feb).
  static DateTime addMonths(DateTime d, int months) {
    final total = d.year * 12 + (d.month - 1) + months;
    final year = total ~/ 12;
    final month = total % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, math.min(d.day, lastDay));
  }

  static int daysBetween(DateTime from, DateTime to) =>
      dayOnly(to).difference(dayOnly(from)).inDays;

  static bool isLeapYear(int year) => (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

  static int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

  /// Number of days in a "month" for conversions: the average Gregorian month.
  static const double averageDaysPerMonth = 30.436875;

  /// Converts a term into whole months (rounded up), used for EMI schedules. Days are an average-month approximation.
  static int termToMonths(double value, TermUnit unit) => switch (unit) {
        TermUnit.days => (value / averageDaysPerMonth).ceil(),
        TermUnit.months => value.ceil(),
        TermUnit.years => (value * 12).ceil(),
      };

  /// End date of a term that starts on [start]. Days are exact; months and years use calendar months.
  static DateTime termEnd(DateTime start, double value, TermUnit unit) => switch (unit) {
        TermUnit.days => dayOnly(start).add(Duration(days: value.round())),
        TermUnit.months => addMonths(start, value.round()),
        TermUnit.years => addMonths(start, (value * 12).round()),
      };
}

enum TermUnit { days, months, years }

extension TermUnitLabel on TermUnit {
  String get label => switch (this) {
        TermUnit.days => 'Days',
        TermUnit.months => 'Months',
        TermUnit.years => 'Years',
      };
}

/// Exact age in years, months and days, as people state it ("27 years, 4 months, 3 days").
class AgeResult {
  const AgeResult({
    required this.years,
    required this.months,
    required this.days,
    required this.totalDays,
    required this.totalWeeks,
    required this.totalMonths,
    required this.nextBirthday,
    required this.daysToNextBirthday,
    required this.bornOn,
  });

  final int years;
  final int months;
  final int days;
  final int totalDays;
  final int totalWeeks;
  final int totalMonths;
  final DateTime nextBirthday;
  final int daysToNextBirthday;
  final String bornOn;
}

class AgeCalc {
  AgeCalc._();

  static const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

  /// Throws [ArgumentError] when the birth date is after the calculation date.
  static AgeResult between({required DateTime birth, required DateTime on}) {
    final b = DateCalc.dayOnly(birth);
    final o = DateCalc.dayOnly(on);
    if (b.isAfter(o)) throw ArgumentError('Date of birth cannot be after the date you calculate on.');

    var years = o.year - b.year;
    final anniversaryThisYear = DateTime(o.year, b.month, math.min(b.day, DateCalc.daysInMonth(o.year, b.month)));
    if (o.isBefore(anniversaryThisYear)) years--;

    final lastBirthday = DateCalc.addMonths(b, years * 12);
    var months = (o.year - lastBirthday.year) * 12 + (o.month - lastBirthday.month);
    if (DateCalc.addMonths(lastBirthday, months).isAfter(o)) months--;
    final anchor = DateCalc.addMonths(lastBirthday, months);
    final days = o.difference(anchor).inDays;

    final totalDays = o.difference(b).inDays;
    final totalMonths = years * 12 + months;

    var next = DateTime(o.year, b.month, math.min(b.day, DateCalc.daysInMonth(o.year, b.month)));
    if (!next.isAfter(o) && !DateCalc.dayOnly(next).isAtSameMomentAs(o)) {
      next = DateTime(o.year + 1, b.month, math.min(b.day, DateCalc.daysInMonth(o.year + 1, b.month)));
    }

    return AgeResult(
      years: years,
      months: months,
      days: days,
      totalDays: totalDays,
      totalWeeks: totalDays ~/ 7,
      totalMonths: totalMonths,
      nextBirthday: next,
      daysToNextBirthday: next.difference(o).inDays,
      bornOn: _weekdays[b.weekday - 1],
    );
  }
}

/// Rent over a period: monthly rent that rises by a yearly percentage. Returns the total and the rent for each year.
class RentYear {
  const RentYear({required this.year, required this.monthlyRent, required this.yearTotal});

  final int year;
  final double monthlyRent;
  final double yearTotal;
}

class RentResult {
  const RentResult({required this.totalRent, required this.finalMonthlyRent, required this.years, required this.months});

  final double totalRent;
  final double finalMonthlyRent;
  final List<RentYear> years;
  final int months;
}

class RentCalc {
  RentCalc._();

  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  /// Totals rent for [months] months. The rent steps up by [yearlyIncreasePercent] at the start of each new lease year.
  static RentResult calculate({
    required double monthlyRent,
    required double yearlyIncreasePercent,
    required int months,
  }) {
    if (monthlyRent <= 0) throw ArgumentError('Monthly rent must be greater than zero.');
    if (months <= 0) throw ArgumentError('The rental period must be at least one month.');
    if (yearlyIncreasePercent < 0) throw ArgumentError('The yearly increase cannot be negative.');

    var total = 0.0;
    var rent = monthlyRent;
    final years = <RentYear>[];
    var remaining = months;
    var year = 1;
    while (remaining > 0) {
      final inThisYear = math.min(12, remaining);
      final yearTotal = _round2(rent * inThisYear);
      years.add(RentYear(year: year, monthlyRent: _round2(rent), yearTotal: yearTotal));
      total += yearTotal;
      remaining -= inThisYear;
      rent = rent * (1 + yearlyIncreasePercent / 100);
      year++;
    }
    return RentResult(
      totalRent: _round2(total),
      finalMonthlyRent: _round2(rent / (1 + yearlyIncreasePercent / 100)),
      years: years,
      months: months,
    );
  }
}
