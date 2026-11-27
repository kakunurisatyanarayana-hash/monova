import 'dart:math' as math;

/// Indian income tax estimate for an individual, from salary, rent and other income.
///
/// Slabs, rebate, standard deductions and deduction limits as published for FY 2026-27 (assessment year 2027-28).
/// Not covered: capital gains at special rates, senior-citizen slabs, other allowances (LTA, meal and
/// telephone), surcharge marginal relief, and advance-tax interest. Check the official rules on
/// incometax.gov.in before you file, and use your employer's Form 16 or payroll figures where you have them.
const taxRulesYear = 'FY 2026-27 (assessment year 2027-28)';

const _noLimit = 9000000000000000;

class TaxSlab {
  const TaxSlab(this.upTo, this.percent);

  /// Top of this band, in rupees.
  final int upTo;
  final int percent;
}

const newRegimeSlabs = [
  TaxSlab(400000, 0),
  TaxSlab(800000, 5),
  TaxSlab(1200000, 10),
  TaxSlab(1600000, 15),
  TaxSlab(2000000, 20),
  TaxSlab(2400000, 25),
  TaxSlab(_noLimit, 30),
];

const oldRegimeSlabs = [
  TaxSlab(250000, 0),
  TaxSlab(500000, 5),
  TaxSlab(1000000, 20),
  TaxSlab(_noLimit, 30),
];

/// Everything the person enters, in rupees a year.
class TaxInputs {
  const TaxInputs({
    this.salary = 0,
    this.basic = 0,
    this.hraReceived = 0,
    this.rentPaid = 0,
    this.metroCity = false,
    this.otherIncome = 0,
    this.savingsInterest = 0,
    this.professionalTax = 0,
    this.employerNps = 0,
    this.section80c = 0,
    this.section80d = 0,
    this.homeLoanInterest = 0,
    this.npsSelf = 0,
  });

  /// Gross salary for the year, including basic and HRA, before any deduction.
  final int salary;

  /// Basic salary for the year. Needed for HRA and employer NPS limits.
  final int basic;

  /// HRA the employer pays for the year.
  final int hraReceived;

  /// Rent you pay for the year, for the HRA exemption.
  final int rentPaid;

  /// Lives in Delhi, Mumbai, Kolkata, Chennai or Hyderabad, Bengaluru, Pune or Ahmedabad: HRA limit is 50% of basic, not 40%.
  final bool metroCity;

  /// Interest from other sources, rent received, freelance or business profit.
  final int otherIncome;

  /// Interest in savings bank accounts, for the 80TTA deduction.
  final int savingsInterest;

  /// Professional tax paid, deducted in the old regime only, up to 2,500.
  final int professionalTax;

  /// Employer contribution to NPS, section 80CCD(2). Allowed in both regimes, with a limit on basic.
  final int employerNps;

  /// Section 80C: PF, life insurance, ELSS and similar. Limit 1,50,000.
  final int section80c;

  /// Section 80D: health insurance for self and family. Limit 25,000.
  final int section80d;

  /// Section 24(b): interest on a self-occupied home loan. Limit 2,00,000.
  final int homeLoanInterest;

  /// Section 80CCD(1B): NPS you add yourself. Limit 50,000.
  final int npsSelf;
}

/// One deduction in a regime, with its label and the amount taken off.
class LineItem {
  const LineItem(this.label, this.amount);

  final String label;
  final int amount;
}

class TaxBreakdown {
  const TaxBreakdown({
    required this.taxableIncome,
    required this.slabTax,
    required this.rebate,
    required this.taxAfterRebate,
    required this.surcharge,
    required this.cess,
  });

  final int taxableIncome;

  /// Tax from the slabs before any rebate.
  final int slabTax;

  /// Reduction from the section 87A rebate, or marginal relief above the rebate limit.
  final int rebate;
  final int taxAfterRebate;
  final int surcharge;

  /// Health and education cess, 4% of tax plus surcharge.
  final int cess;

  int get total => taxAfterRebate + surcharge + cess;
}

class RegimeResult {
  const RegimeResult({
    required this.isNew,
    required this.income,
    required this.deductions,
    required this.taxable,
    required this.breakdown,
  });

  final bool isNew;

  /// Salary plus other income, before deductions.
  final int income;
  final List<LineItem> deductions;
  final int taxable;
  final TaxBreakdown breakdown;

  int get total => breakdown.total;
}

/// Tax from the slabs alone, for a taxable income in rupees.
int slabTax(int income, List<TaxSlab> slabs) {
  var tax = 0.0;
  var lower = 0;
  for (final s in slabs) {
    if (income <= lower) break;
    final top = math.min(income, s.upTo);
    tax += (top - lower) * s.percent / 100;
    lower = s.upTo;
  }
  return tax.round();
}

/// Surcharge on tax, by total taxable income. The new regime stops at 25%.
int surchargePercent(int income, {required bool newRegime}) {
  if (income > 50000000) return newRegime ? 25 : 37;
  if (income > 20000000) return 25;
  if (income > 10000000) return 15;
  if (income > 5000000) return 10;
  return 0;
}

/// Full tax for one regime. [taxable] is the income after that regime's deductions.
TaxBreakdown computeTax({required int taxable, required bool newRegime}) {
  final slabs = newRegime ? newRegimeSlabs : oldRegimeSlabs;
  final rebateLimit = newRegime ? 1200000 : 500000;
  final maxRebate = newRegime ? 60000 : 12500;
  final tax = slabTax(taxable, slabs);
  final int afterRebate;
  if (taxable <= rebateLimit) {
    // Section 87A: no tax up to the limit.
    afterRebate = _floorZero(tax - maxRebate);
  } else {
    // Marginal relief: just above the limit, tax cannot be more than the income above it.
    afterRebate = _least(tax, taxable - rebateLimit);
  }
  final surcharge = (afterRebate * surchargePercent(taxable, newRegime: newRegime) / 100).round();
  final cess = ((afterRebate + surcharge) * 4 / 100).round();
  return TaxBreakdown(
    taxableIncome: taxable,
    slabTax: tax,
    rebate: tax - afterRebate,
    taxAfterRebate: afterRebate,
    surcharge: surcharge,
    cess: cess,
  );
}

/// HRA exemption under section 10(13A): the least of HRA received, rent paid above 10% of basic,
/// and 50% (metro) or 40% (other cities) of basic. Zero when any of the figures is missing.
int hraExemption({required int basic, required int hraReceived, required int rentPaid, required bool metroCity}) {
  if (basic <= 0 || hraReceived <= 0 || rentPaid <= 0) return 0;
  final rentAboveTenPercent = _floorZero(rentPaid - basic ~/ 10);
  final cityLimit = basic * (metroCity ? 50 : 40) ~/ 100;
  return _least(hraReceived, _least(rentAboveTenPercent, cityLimit));
}

/// Employer NPS deduction limit: 14% of basic in the new regime, 10% in the old.
int _employerNpsLimit(int basic, {required bool newRegime}) => basic * (newRegime ? 14 : 10) ~/ 100;

RegimeResult _finish({required bool isNew, required int income, required List<LineItem> items}) {
  var taken = 0;
  for (final item in items) {
    taken += item.amount;
  }
  final taxable = _floorZero(income - taken);
  return RegimeResult(
    isNew: isNew,
    income: income,
    deductions: items,
    taxable: taxable,
    breakdown: computeTax(taxable: taxable, newRegime: isNew),
  );
}

/// New regime: standard deduction of 75,000 on salary, and employer NPS. No HRA, 80C or other chapter VI-A deductions.
RegimeResult newRegimeResult(TaxInputs i) {
  final items = <LineItem>[
    if (i.salary > 0) const LineItem('Standard deduction', 75000),
  ];
  final nps = _least(i.employerNps, _employerNpsLimit(i.basic, newRegime: true));
  if (nps > 0) items.add(LineItem('Employer NPS, 80CCD(2)', nps));
  return _finish(isNew: true, income: i.salary + i.otherIncome, items: items);
}

/// Old regime: standard deduction of 50,000, HRA exemption, professional tax and the chapter VI-A deductions.
RegimeResult oldRegimeResult(TaxInputs i) {
  final items = <LineItem>[];
  if (i.salary > 0) items.add(const LineItem('Standard deduction', 50000));
  final hra = hraExemption(basic: i.basic, hraReceived: i.hraReceived, rentPaid: i.rentPaid, metroCity: i.metroCity);
  if (hra > 0) items.add(LineItem('HRA exemption', hra));
  final tax = _least(i.professionalTax, 2500);
  if (tax > 0) items.add(LineItem('Professional tax', tax));
  final c80 = _least(i.section80c, 150000);
  if (c80 > 0) items.add(LineItem('80C: PF, insurance, ELSS', c80));
  final d80 = _least(i.section80d, 25000);
  if (d80 > 0) items.add(LineItem('80D: health insurance', d80));
  final homeLoan = _least(i.homeLoanInterest, 200000);
  if (homeLoan > 0) items.add(LineItem('24(b): home loan interest', homeLoan));
  final npsSelf = _least(i.npsSelf, 50000);
  if (npsSelf > 0) items.add(LineItem('80CCD(1B): your NPS', npsSelf));
  final npsEmployer = _least(i.employerNps, _employerNpsLimit(i.basic, newRegime: false));
  if (npsEmployer > 0) items.add(LineItem('80CCD(2): employer NPS', npsEmployer));
  final savings = _least(i.savingsInterest, 10000);
  if (savings > 0) items.add(LineItem('80TTA: savings interest', savings));
  return _finish(isNew: false, income: i.salary + i.otherIncome, items: items);
}

/// The smaller of two amounts.
int _least(int a, int b) => a < b ? a : b;

/// Zero for negative amounts, otherwise the amount.
int _floorZero(int value) => value < 0 ? 0 : value;
