import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'entry_store.dart';
import 'loans.dart';
import 'money_plans.dart';
import 'property_money.dart';
import 'property_store.dart';

/// Rupee amounts in the report. The PDF's built-in font has no rupee sign, so amounts read "Rs".
final _rupees = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs ', decimalDigits: 2);

String rupees(int cents) => _rupees.format(cents / 100);

class CategoryTotal {
  const CategoryTotal(this.category, this.cents);

  final String category;
  final int cents;
}

class BudgetLine {
  const BudgetLine(this.category, this.spentCents, this.limitCents);

  final String category;
  final int spentCents;
  final int limitCents;
}

/// Everything in one month's report, worked out from the records on this phone.
class MonthlyReport {
  const MonthlyReport({
    required this.year,
    required this.month,
    required this.moneyIn,
    required this.moneyOut,
    required this.categories,
    required this.budgets,
    required this.loansOutstanding,
    required this.loansEachMonth,
    required this.rentCollected,
    required this.propertyExpenses,
    required this.depositsHeld,
  });

  final int year;
  final int month;
  final int moneyIn;
  final int moneyOut;

  /// Spending by category this month, largest first.
  final List<CategoryTotal> categories;
  final List<BudgetLine> budgets;

  /// Still owed on loans and borrowing, across all open items.
  final int loansOutstanding;

  /// Instalments due each month on open loans.
  final int loansEachMonth;
  final int rentCollected;
  final int propertyExpenses;
  final int depositsHeld;

  int get leftOver => moneyIn - moneyOut;
}

/// Builds the report for one month. Nothing is sent anywhere; the inputs are the records already on the device.
MonthlyReport buildMonthlyReport({
  required int year,
  required int month,
  required List<MoneyEntry> entries,
  required List<Budget> budgets,
  required List<Loan> loans,
  required PropertyBook book,
}) {
  final summary = monthSummary(entries, year, month);
  final byCategory = <String, int>{};
  for (final e in entries) {
    if (e.income || e.date.year != year || e.date.month != month) continue;
    byCategory[e.category] = (byCategory[e.category] ?? 0) + e.cents;
  }
  final categories = [for (final entry in byCategory.entries) CategoryTotal(entry.key, entry.value)]
    ..sort((a, b) => b.cents.compareTo(a.cents));
  final open = [for (final l in loans) if (!l.finished) l];
  final property = monthMoney(book, year: year, month: month);
  return MonthlyReport(
    year: year,
    month: month,
    moneyIn: summary.income,
    moneyOut: summary.spent,
    categories: categories,
    budgets: [
      for (final b in budgets) BudgetLine(b.category, spentInCategory(entries, b.category, year, month), b.limitCents),
    ],
    loansOutstanding: open.fold(0, (s, l) => s + l.outstandingCents()),
    loansEachMonth: open.fold(0, (s, l) => s + l.emiCents),
    rentCollected: property.rentCents,
    propertyExpenses: property.expenseCents,
    depositsHeld: property.depositsHeldCents,
  );
}

const _monthNames = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

/// The report as a PDF, ready to save, share or print.
Future<Uint8List> monthlyReportPdf(MonthlyReport r, {DateTime? generatedOn}) async {
  final doc = pw.Document();
  final heading = pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold);
  final muted = const pw.TextStyle(fontSize: 10, color: PdfColors.grey700);
  final when = generatedOn ?? DateTime.now();

  pw.Widget table(List<String> headers, List<List<String>> rows) => pw.TableHelper.fromTextArray(
        headers: headers,
        data: rows,
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        cellStyle: const pw.TextStyle(fontSize: 10),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellAlignments: {for (var i = 0; i < headers.length; i++) i: i == headers.length - 1 ? pw.Alignment.centerRight : pw.Alignment.centerLeft},
      );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(36),
    build: (context) => [
      pw.Text('MONOVA monthly report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.Text('${_monthNames[r.month - 1]} ${r.year}', style: const pw.TextStyle(fontSize: 13)),
      pw.Text('Made on ${dayLabelFor(when)} from the records on this phone', style: muted),
      pw.SizedBox(height: 16),
      pw.Text('Summary', style: heading),
      pw.SizedBox(height: 6),
      table(['Item', 'Amount'], [
        ['Money in', rupees(r.moneyIn)],
        ['Money out', rupees(r.moneyOut)],
        ['Left over', rupees(r.leftOver)],
      ]),
      pw.SizedBox(height: 16),
      pw.Text('Spending by category', style: heading),
      pw.SizedBox(height: 6),
      if (r.categories.isEmpty) pw.Text('No spending recorded this month.', style: muted)
      else table(['Category', 'Amount'], [for (final c in r.categories) [c.category, rupees(c.cents)]]),
      if (r.budgets.isNotEmpty) ...[
        pw.SizedBox(height: 16),
        pw.Text('Budgets', style: heading),
        pw.SizedBox(height: 6),
        table(['Category', 'Spent', 'Limit', 'Status'], [
          for (final b in r.budgets)
            [
              b.category,
              rupees(b.spentCents),
              rupees(b.limitCents),
              b.spentCents > b.limitCents ? 'Over budget' : (b.spentCents >= b.limitCents * 0.8 ? 'Close to limit' : 'Within budget'),
            ],
        ]),
      ],
      pw.SizedBox(height: 16),
      pw.Text('Loans and borrowing', style: heading),
      pw.SizedBox(height: 6),
      table(['Item', 'Amount'], [
        ['Still to repay (all open loans)', rupees(r.loansOutstanding)],
        ['Instalments due each month', rupees(r.loansEachMonth)],
      ]),
      pw.SizedBox(height: 16),
      pw.Text('Property', style: heading),
      pw.SizedBox(height: 6),
      table(['Item', 'Amount'], [
        ['Rent collected this month', rupees(r.rentCollected)],
        ['Property expenses this month', rupees(r.propertyExpenses)],
        ['Deposits held (not income)', rupees(r.depositsHeld)],
      ]),
      pw.SizedBox(height: 18),
      pw.Text(
        'Amounts are in Indian rupees (Rs). Deposits are kept separately and are not counted as income. '
        'This report is a personal record, not a tax or bank statement.',
        style: muted,
      ),
    ],
  ));
  return doc.save();
}

String dayLabelFor(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
