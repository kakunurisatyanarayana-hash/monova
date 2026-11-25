import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// One entry on the Services menu. A route means it works now. No route means it's coming soon.
class ServiceItem {
  const ServiceItem({required this.title, required this.icon, this.route, this.note});

  final String title;
  final IconData icon;
  final String? route;
  /// Shown under "Coming soon" items: what is needed before they can work.
  final String? note;
}

class ServiceSection {
  const ServiceSection(this.title, this.items);

  final String title;
  final List<ServiceItem> items;
}

const _sections = [
  ServiceSection('Money tools', [
    ServiceItem(title: 'Loan calculator', icon: Icons.account_balance_rounded, route: '/tools/emi'),
    ServiceItem(title: 'Interest calculator', icon: Icons.percent_rounded, route: '/tools/interest'),
    ServiceItem(title: 'GST calculator', icon: Icons.receipt_long_rounded, route: '/tools/gst'),
    ServiceItem(title: 'Scientific calculator', icon: Icons.calculate_outlined, route: '/tools/calculator'),
    ServiceItem(title: 'Bill split', icon: Icons.call_split_rounded, route: '/tools/split'),
    ServiceItem(title: 'Age calculator', icon: Icons.cake_rounded, route: '/tools/age'),
    ServiceItem(title: 'Rent calculator', icon: Icons.house_rounded, route: '/tools/rent'),
  ]),
  ServiceSection('Your money', [
    ServiceItem(title: 'Accounts', icon: Icons.account_balance_wallet_rounded, route: '/accounts'),
    ServiceItem(title: 'Credit cards and bills', icon: Icons.credit_card_rounded, route: '/cards'),
    ServiceItem(title: 'Lending and borrowing', icon: Icons.handshake_rounded, route: '/lending'),
    ServiceItem(title: 'Loans and EMI', icon: Icons.directions_car_rounded, route: '/loans'),
    ServiceItem(title: 'Budgets and savings', icon: Icons.savings_rounded, route: '/planning'),
    ServiceItem(title: 'Recurring entries', icon: Icons.repeat_rounded, route: '/recurring'),
    ServiceItem(title: 'Groups and splitting', icon: Icons.groups_rounded, route: '/groups'),
    ServiceItem(title: 'Insights', icon: Icons.insights_rounded, route: '/insights'),
    ServiceItem(title: 'Passwords and notes', icon: Icons.lock_rounded, route: '/vault'),
    ServiceItem(title: 'Credit book (udhaar with daily interest)', icon: Icons.menu_book_rounded, route: '/ledger'),
    ServiceItem(title: 'Saved cards (details and photo)', icon: Icons.credit_card_rounded, route: '/saved-cards'),
  ]),
  ServiceSection('Recharges and bill payments', [
    ServiceItem(title: 'Mobile recharge', icon: Icons.smartphone_rounded,
        note: 'Needs a licensed payment partner (BBPS or aggregator).'),
    ServiceItem(title: 'DTH recharge', icon: Icons.tv_rounded,
        note: 'Needs a licensed payment partner (BBPS or aggregator).'),
    ServiceItem(title: 'Electricity bill', icon: Icons.bolt_rounded,
        note: 'Needs a licensed bill-payment partner (BBPS).'),
    ServiceItem(title: 'Water and gas bill', icon: Icons.water_drop_rounded,
        note: 'Needs a licensed bill-payment partner (BBPS).'),
    ServiceItem(title: 'Broadband bill', icon: Icons.wifi_rounded,
        note: 'Needs a licensed bill-payment partner (BBPS).'),
    ServiceItem(title: 'Insurance premium', icon: Icons.shield_rounded,
        note: 'Needs insurer or payment partner agreements.'),
    ServiceItem(title: 'FASTag recharge', icon: Icons.toll_rounded,
        note: 'Needs a licensed payment partner.'),
    ServiceItem(title: 'Pay credit card bill from app', icon: Icons.payments_rounded,
        note: 'Needs a licensed payment partner. Recording a bill payment already works under Credit cards.'),
  ]),
  ServiceSection('Bank connections', [
    ServiceItem(title: 'Bank account sync', icon: Icons.sync_rounded,
        note: 'Needs an RBI-regulated Account Aggregator partner.'),
    ServiceItem(title: 'Import bank statement (PDF or CSV)', icon: Icons.upload_file_rounded,
        note: 'Planned. Works without a partner, but not yet built.'),
    ServiceItem(title: 'Read bank SMS', icon: Icons.sms_rounded,
        note: 'Restricted on Google Play. Not planned for the store version.'),
    ServiceItem(title: 'Credit score', icon: Icons.speed_rounded,
        note: 'Needs a licensed credit bureau partner.'),
    ServiceItem(title: 'PAN check', icon: Icons.badge_rounded,
        note: 'Needs a licensed verification partner.'),
  ]),
  ServiceSection('Sign-in and reminders', [
    ServiceItem(title: 'Google sign-in', icon: Icons.login_rounded,
        note: 'Needs a Google client ID from your Google Cloud project (free).'),
    ServiceItem(title: 'Sign in with mobile number', icon: Icons.phone_iphone_rounded,
        note: 'Works on the server. Needs an SMS provider and DLT registration in India.'),
    ServiceItem(title: 'Due-date reminders', icon: Icons.notifications_active_rounded,
        note: 'Planned: notifications for bills, EMIs and card due dates.'),
  ]),
  ServiceSection('Other', [
    ServiceItem(title: 'Backup and restore', icon: Icons.backup_rounded, route: '/backup'),
    ServiceItem(title: 'Export my data (CSV)', icon: Icons.download_rounded,
        note: 'Planned.'),
    ServiceItem(title: 'Investments (mutual funds, FD, RD)', icon: Icons.trending_up_rounded,
        note: 'Planned.'),
    ServiceItem(title: 'Tax summary', icon: Icons.summarize_rounded,
        note: 'Planned.'),
    ServiceItem(title: 'iPhone app', icon: Icons.devices_rounded,
        note: 'Needs a Mac for building and an Apple developer account for installing.'),
  ]),
];

/// Every feature in one menu. On wide screens the sections sit side by side in columns.
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Scaffold(
      appBar: AppBar(title: const Text('All services')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final gap = 16.0;
          final available = constraints.maxWidth - 32;
          final columnWidth = wide ? (available - gap * 2) / 3 : available;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                SizedBox(
                  width: available,
                  child: Text(
                    'Tap any working service to open it. "Coming soon" items are planned and show what they need first.',
                    style: TextStyle(color: c.muted, fontSize: 12),
                  ),
                ),
                for (final section in _sections)
                  SizedBox(
                    width: columnWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionTitle(section.title),
                        const SizedBox(height: 8),
                        MonovaCard(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [for (final item in section.items) _ServiceRow(item: item)],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.item});

  final ServiceItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final available = item.route != null;
    return ListTile(
      enabled: available,
      onTap: available ? () => context.push(item.route!) : null,
      leading: CircleAvatar(
        backgroundColor: c.border,
        child: Icon(item.icon, color: available ? c.accentStart : c.muted, size: 18),
      ),
      title: Text(item.title, style: TextStyle(fontWeight: FontWeight.w700, color: available ? c.ink : c.muted)),
      subtitle: available
          ? null
          : Text(item.note ?? 'Coming soon', style: TextStyle(color: c.muted, fontSize: 12)),
      trailing: available
          ? Icon(Icons.chevron_right_rounded, color: c.muted)
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
              child: Text('Coming soon', style: TextStyle(color: c.warning, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
    );
  }
}
