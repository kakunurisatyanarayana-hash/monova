import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/entry_store.dart';
import '../../core/format.dart';
import '../../core/i18n.dart';
import '../../core/theme.dart';
import '../../core/money_plans.dart';
import '../../core/widgets.dart';

/// Money in one place: this month's totals, then each money record with one tap to open it.
class MoneyHubScreen extends StatefulWidget {
  const MoneyHubScreen({super.key});

  @override
  State<MoneyHubScreen> createState() => _MoneyHubScreenState();
}

class _MoneyHubScreenState extends State<MoneyHubScreen> {
  MonthSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await PlansStore.runRecurring(DateTime.now());
    try {
      final entries = await EntryStore.loadEntries();
      final now = DateTime.now();
      final s = monthSummary(entries, now.year, now.month);
      if (mounted) setState(() => _summary = s);
    } catch (_) {
      if (mounted) setState(() => _summary = const MonthSummary(income: 0, spent: 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final now = DateTime.now();
    final s = _summary;
    return Scaffold(
      appBar: AppBar(title: Text(tr('nav_money'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          MonovaCard(
            gradient: c.hero,
            padding: const EdgeInsets.all(18),
            child: s == null
                ? const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(monthLabel(now.year, now.month), style: TextStyle(color: c.onAccent.withValues(alpha: 0.9), fontSize: 12)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _Figure(label: tr('money_in'), value: money(s.income / 100), color: c.onAccent)),
                          Expanded(child: _Figure(label: tr('money_out'), value: money(s.spent / 100), color: c.onAccent)),
                          Expanded(child: _Figure(label: tr('money_left'), value: money(s.savings / 100), color: c.onAccent)),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 18),
          SectionTitle(tr('money_record_check')),
          const SizedBox(height: 8),
          _MoneyTile(icon: Icons.swap_vert_rounded, title: tr('money_income_spending'), subtitle: 'Add what came in or went out, and see the month', route: '/entries'),
          _MoneyTile(icon: Icons.receipt_long_rounded, title: tr('money_purchases'), subtitle: 'What you bought, its warranty and return date', route: '/purchases'),
          _MoneyTile(icon: Icons.account_balance_outlined, title: tr('money_loans'), subtitle: 'Loan instalments, overdue ones, and money you borrowed', route: '/loans'),
          _MoneyTile(icon: Icons.folder_open_rounded, title: tr('money_documents'), subtitle: 'Photos of papers, bills and warranty cards', route: '/documents'),
          _MoneyTile(icon: Icons.picture_as_pdf_rounded, title: tr('money_report'), subtitle: 'Money in and out, spending, budgets and loans as a PDF', route: '/report'),
          _MoneyTile(icon: Icons.trending_up_rounded, title: 'SIP and monthly savings', subtitle: 'Monthly investments due, unpaid months, and what you have put in', route: '/sip'),
          _MoneyTile(icon: Icons.event_repeat_rounded, title: tr('money_plans'), subtitle: 'Monthly limits, savings targets, and rent or salary every month', route: '/plans'),
          _MoneyTile(icon: Icons.menu_book_rounded, title: tr('money_credit_book'), subtitle: 'Money you gave on credit, with daily interest', route: '/ledger'),
          _MoneyTile(icon: Icons.call_split_rounded, title: tr('money_split'), subtitle: 'Share costs and see who pays whom', route: '/tools/split'),
          _MoneyTile(icon: Icons.apartment_rounded, title: tr('money_property'), subtitle: 'Rent received, deposits and running costs', route: '/property'),
          _MoneyTile(icon: Icons.credit_card_rounded, title: tr('money_cards'), subtitle: 'Card details with a photo, last four digits only', route: '/saved-cards'),
          _MoneyTile(icon: Icons.calculate_outlined, title: tr('money_calculators'), subtitle: 'Loan, interest, GST, age and more', route: '/tools'),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 11)),
      ],
    );
  }
}

class _MoneyTile extends StatelessWidget {
  const _MoneyTile({required this.icon, required this.title, required this.subtitle, required this.route});

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MonovaCard(
        padding: const EdgeInsets.all(14),
        onTap: () => context.push(route),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: c.accentStart.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: c.accentStart),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: c.muted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.muted),
          ],
        ),
      ),
    );
  }
}
