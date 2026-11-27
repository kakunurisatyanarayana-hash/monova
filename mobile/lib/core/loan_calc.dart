import 'dart:math' as math;

import 'finance_calc.dart';

/// Indian loan products with indicative defaults. Rates, tenures and fees vary by lender, profile and month:
/// every default is editable in the calculator and must be checked against the lender's sanction letter.
class LoanProduct {
  const LoanProduct({
    required this.name,
    required this.icon,
    required this.ratePercent,
    required this.tenureMonths,
    required this.processingFeePercent,
    required this.maxTenureMonths,
    required this.note,
  });

  final String name;
  final String icon;
  final double ratePercent;
  final int tenureMonths;
  final double processingFeePercent;
  final int maxTenureMonths;
  final String note;

  static const all = <LoanProduct>[
    LoanProduct(name: 'Home loan', icon: 'home', ratePercent: 7.25, tenureMonths: 240, processingFeePercent: 0.5, maxTenureMonths: 360, note: 'Starting rates at SBI, HDFC and ICICI (Nov 2026). Processing fee 0.25% to 2% plus GST. Stamp duty is extra.'),
    LoanProduct(name: 'Personal loan', icon: 'person', ratePercent: 12.0, tenureMonths: 60, processingFeePercent: 2.0, maxTenureMonths: 72, note: 'Bank rates typically 10% to 16%; NBFCs can be higher. Processing fee 0.5% to 3% plus GST.'),
    LoanProduct(name: 'Car loan', icon: 'car', ratePercent: 8.5, tenureMonths: 84, processingFeePercent: 1.0, maxTenureMonths: 96, note: 'New car rates about 7.6% to 11.5%. Used cars are higher.'),
    LoanProduct(name: 'Two-wheeler loan', icon: 'bike', ratePercent: 10.5, tenureMonths: 36, processingFeePercent: 1.0, maxTenureMonths: 48, note: 'Bank rates typically 8.75% to 14.5%. Your credit score matters most.'),
    LoanProduct(name: 'Education loan', icon: 'school', ratePercent: 9.5, tenureMonths: 120, processingFeePercent: 1.0, maxTenureMonths: 180, note: 'NOT YET CHECKED against current listings. Confirm the rate and fee with the lender.'),
    LoanProduct(name: 'Business loan', icon: 'business', ratePercent: 13.0, tenureMonths: 60, processingFeePercent: 2.0, maxTenureMonths: 84, note: 'NOT YET CHECKED against current listings. Confirm the rate and fee with the lender.'),
    LoanProduct(name: 'Loan against property', icon: 'property', ratePercent: 10.0, tenureMonths: 180, processingFeePercent: 1.0, maxTenureMonths: 240, note: 'NOT YET CHECKED against current listings. Confirm the rate and fee with the lender.'),
    LoanProduct(name: 'Gold loan', icon: 'gold', ratePercent: 9.5, tenureMonths: 12, processingFeePercent: 1.0, maxTenureMonths: 36, note: 'NOT YET CHECKED against current listings. Confirm the rate and fee with the lender.'),
  ];
}

/// Everything the lender can charge on top of interest. GST applies to service fees only, as per Indian GST rules on lending services.
class LoanCharges {
  const LoanCharges({
    this.processingFeePercent = 0,
    this.processingFeeFixed = 0,
    this.documentationFee = 0,
    this.valuationFee = 0,
    this.legalFee = 0,
    this.insurancePremium = 0,
    this.stampDutyAndRegistration = 0,
    this.gstPercent = 18,
    this.applyGstOnServiceFees = true,
  });

  final double processingFeePercent;
  final double processingFeeFixed;
  final double documentationFee;
  final double valuationFee;
  final double legalFee;
  /// Insurance and stamp duty are not GST-bearing service fees in this calculation, so they are added without GST.
  final double insurancePremium;
  final double stampDutyAndRegistration;
  final double gstPercent;
  final bool applyGstOnServiceFees;
}

class LoanInput {
  const LoanInput({
    required this.principal,
    required this.annualRatePercent,
    required this.tenureMonths,
    this.charges = const LoanCharges(),
  });

  final double principal;
  final double annualRatePercent;
  final int tenureMonths;
  final LoanCharges charges;
}

class LoanScheduleRow {
  const LoanScheduleRow({required this.month, required this.emi, required this.interest, required this.principal, required this.balance});

  final int month;
  final double emi;
  final double interest;
  final double principal;
  final double balance;
}

class LoanResult {
  const LoanResult({
    required this.emi,
    required this.totalInterest,
    required this.serviceFees,
    required this.gstOnFees,
    required this.otherCharges,
    required this.upfrontCharges,
    required this.totalCost,
    required this.netDisbursed,
    required this.effectiveAnnualRatePercent,
    required this.schedule,
  });

  final double emi;
  /// Interest over the full tenure.
  final double totalInterest;
  /// Processing, documentation, valuation and legal fees before GST.
  final double serviceFees;
  final double gstOnFees;
  /// Insurance and stamp duty, which carry no GST in this model.
  final double otherCharges;
  /// Everything paid upfront, besides the principal being repaid: fees + GST + other charges.
  final double upfrontCharges;
  /// Principal + interest + all charges. What the borrower truly pays.
  final double totalCost;
  /// What the borrower actually receives: principal minus upfront charges.
  final double netDisbursed;
  /// APR: the rate the borrower really pays once upfront charges are counted (monthly IRR x 12, as in Indian key-facts statements).
  final double effectiveAnnualRatePercent;
  final List<LoanScheduleRow> schedule;
}

class LoanCalculator {
  LoanCalculator._();

  static double round2(double v) => (v * 100).roundToDouble() / 100;

  static LoanResult calculate(LoanInput input) {
    final p = input.principal;
    final n = input.tenureMonths;
    if (p <= 0 || n <= 0 || input.annualRatePercent < 0) {
      throw ArgumentError('Amount and tenure must be positive, and the rate cannot be negative.');
    }
    final c = input.charges;

    final processing = round2(p * c.processingFeePercent / 100 + c.processingFeeFixed);
    final serviceFees = round2(processing + c.documentationFee + c.valuationFee + c.legalFee);
    final gst = c.applyGstOnServiceFees ? round2(serviceFees * c.gstPercent / 100) : 0.0;
    final other = round2(c.insurancePremium + c.stampDutyAndRegistration);
    final upfront = round2(serviceFees + gst + other);

    final emi = FinanceCalc.emi(principal: p, annualRatePercent: input.annualRatePercent, months: n).emi;
    final schedule = _schedule(p, input.annualRatePercent, n, emi);
    final totalInterest = round2(schedule.fold<double>(0, (a, r) => a + r.interest));
    final totalPaid = round2(schedule.fold<double>(0, (a, r) => a + r.emi));

    final netDisbursed = round2(p - upfront);
    final monthlyIrr = _irrMonthly(netDisbursed, emi, n);
    // APR as used in Indian key-facts statements: monthly IRR x 12. With no charges it equals the stated rate.
    final effectiveAnnual = monthlyIrr * 12 * 100;

    return LoanResult(
      emi: emi,
      totalInterest: totalInterest,
      serviceFees: serviceFees,
      gstOnFees: gst,
      otherCharges: other,
      upfrontCharges: upfront,
      totalCost: round2(totalPaid + upfront),
      netDisbursed: netDisbursed,
      effectiveAnnualRatePercent: double.parse(effectiveAnnual.toStringAsFixed(2)),
      schedule: schedule,
    );
  }

  static List<LoanScheduleRow> _schedule(double p, double annualRate, int n, double emi) {
    final r = annualRate / 12 / 100;
    var balance = p;
    final rows = <LoanScheduleRow>[];
    for (var m = 1; m <= n; m++) {
      final interest = round2(balance * r);
      double principalPart;
      double payment;
      if (m == n) {
        principalPart = round2(balance);
        payment = round2(principalPart + interest);
      } else {
        payment = emi;
        principalPart = round2(payment - interest);
      }
      balance = round2(balance - principalPart);
      rows.add(LoanScheduleRow(month: m, emi: payment, interest: interest, principal: principalPart, balance: math.max(0, balance)));
    }
    return rows;
  }

  /// Monthly rate r such that netDisbursed = sum(emi / (1+r)^k). Bisection on [0, 10%] per month.
  static double _irrMonthly(double netDisbursed, double emi, int n) {
    if (netDisbursed <= 0) return 1;
    double npv(double r) {
      var sum = 0.0;
      for (var k = 1; k <= n; k++) {
        sum += emi / math.pow(1 + r, k);
      }
      return sum - netDisbursed;
    }
    var lo = 0.0, hi = 0.10;
    if (npv(lo) < 0) return 0;
    for (var i = 0; i < 200; i++) {
      final mid = (lo + hi) / 2;
      if (npv(mid) > 0) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// Compares every product at its default terms for the same amount, so the user sees all loan types side by side.
  static List<({LoanProduct product, LoanResult result})> compareAll(double principal) {
    return [
      for (final product in LoanProduct.all)
        (
          product: product,
          result: calculate(LoanInput(
            principal: principal,
            annualRatePercent: product.ratePercent,
            tenureMonths: product.tenureMonths,
            charges: LoanCharges(processingFeePercent: product.processingFeePercent),
          )),
        ),
    ];
  }
}
