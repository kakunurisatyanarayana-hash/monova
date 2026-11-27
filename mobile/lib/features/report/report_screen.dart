import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../core/entry_store.dart';
import '../../core/format.dart';
import '../../core/loans.dart';
import '../../core/monthly_report.dart';
import '../../core/money_plans.dart';
import '../../core/property_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Pick a month, see its summary, then save, share or print it as a PDF. Works without a network.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  MonthlyReport? _report;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    final entries = await EntryStore.loadEntries();
    final budgets = await PlansStore.loadBudgets();
    final loans = await LoanStore.load();
    final (book, _) = await PropertyStore.loadWithRetention(DateTime.now());
    final report = buildMonthlyReport(
      year: _month.year,
      month: _month.month,
      entries: entries,
      budgets: budgets,
      loans: loans,
      book: book,
    );
    if (mounted) setState(() => _report = report);
  }

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
    _build();
  }

  Future<void> _share() async {
    final r = _report;
    if (r == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await monthlyReportPdf(r);
      final name = 'monova-${r.year}-${r.month.toString().padLeft(2, '0')}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('The PDF could not be made. $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _print() async {
    final r = _report;
    if (r == null) return;
    final bytes = await monthlyReportPdf(r);
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'MONOVA ${monthLabel(r.year, r.month)}');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final r = _report;
    final now = DateTime.now();
    final isCurrent = _month.year == now.year && _month.month == now.month;
    return Scaffold(
      appBar: AppBar(title: const Text('Monthly report')),
      body: r == null
          ? const LoadingBox()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                Row(
                  children: [
                    IconButton(tooltip: 'Previous month', icon: const Icon(Icons.chevron_left_rounded), onPressed: () => _shift(-1)),
                    Expanded(
                      child: Text(monthLabel(_month.year, _month.month), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: isCurrent ? null : () => _shift(1),
                    ),
                  ],
                ),
                MonovaCard(
                  gradient: c.hero,
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Expanded(child: _Figure(label: 'Money in', value: money(r.moneyIn / 100), onHero: true)),
                      Expanded(child: _Figure(label: 'Money out', value: money(r.moneyOut / 100), onHero: true)),
                      Expanded(child: _Figure(label: 'Left over', value: money(r.leftOver / 100), onHero: true)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const SectionTitle('Spending by category'),
                const SizedBox(height: 8),
                if (r.categories.isEmpty)
                  MonovaCard(child: Text('No spending recorded this month.', style: TextStyle(color: c.muted)))
                else
                  for (final cat in r.categories)
                    _Row(label: cat.category, value: money(cat.cents / 100), color: c.ink),
                if (r.budgets.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const SectionTitle('Budgets'),
                  const SizedBox(height: 8),
                  for (final b in r.budgets)
                    _Row(
                      label: b.category,
                      value: '${money(b.spentCents / 100)} of ${money(b.limitCents / 100)}',
                      color: b.spentCents > b.limitCents ? c.expense : (b.spentCents >= b.limitCents * 0.8 ? c.warning : c.income),
                    ),
                ],
                const SizedBox(height: 14),
                const SectionTitle('Loans and property'),
                const SizedBox(height: 8),
                _Row(label: 'Still to repay on loans', value: money(r.loansOutstanding / 100), color: c.ink),
                _Row(label: 'Loan instalments each month', value: money(r.loansEachMonth / 100), color: c.ink),
                _Row(label: 'Rent collected', value: money(r.rentCollected / 100), color: c.income),
                _Row(label: 'Property expenses', value: money(r.propertyExpenses / 100), color: c.expense),
                _Row(label: 'Deposits held (not income)', value: money(r.depositsHeld / 100), color: c.muted),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _share,
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: Text(_busy ? 'Making the PDF…' : 'Save or share as PDF'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _print,
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Print'),
                ),
                const SizedBox(height: 10),
                Text(
                  'The PDF is made on this phone. Nothing is uploaded.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 12),
                ),
              ],
            ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.onHero = false});

  final String label;
  final String value;
  final bool onHero;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final fg = onHero ? c.onAccent : c.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: onHero ? c.onAccent.withValues(alpha: 0.9) : c.muted, fontSize: 11)),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MonovaCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
