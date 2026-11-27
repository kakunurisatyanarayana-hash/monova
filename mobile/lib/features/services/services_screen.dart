import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// One entry on the Services menu.
/// A route means the feature is in this build. [needsOnline] marks features that need an account, which the offline build does not have.
/// No route means the feature is planned; [note] says what it needs first.
class ServiceItem {
  const ServiceItem({required this.title, required this.icon, this.route, this.note, this.needsOnline = false});

  final String title;
  final IconData icon;
  final String? route;
  final String? note;
  final bool needsOnline;

  bool available(bool offline) => route != null && (!needsOnline || !offline);
}

class ServiceSection {
  const ServiceSection(this.title, this.items, {this.subtitle});

  final String title;
  final String? subtitle;
  final List<ServiceItem> items;
}

const _sections = [
  ServiceSection('Property and rooms', subtitle: 'Hostels, PGs, hotels and rentals: who is in which room, and which beds are free.', [
    ServiceItem(title: 'Properties and rooms', icon: Icons.apartment_rounded, route: '/property'),
  ]),
  ServiceSection('Monova QR', subtitle: 'Make and scan codes. Invitations, locations, guest entry and any text or link.', [
    ServiceItem(title: 'Monova QR', icon: Icons.qr_code_2_rounded, route: '/qr'),
  ]),
  ServiceSection('Calculators', subtitle: 'Work things out before you decide. No account needed.', [
    ServiceItem(title: 'Loan and EMI', icon: Icons.account_balance_rounded, route: '/tools/emi'),
    ServiceItem(title: 'Interest', icon: Icons.percent_rounded, route: '/tools/interest'),
    ServiceItem(title: 'GST', icon: Icons.receipt_long_rounded, route: '/tools/gst'),
    ServiceItem(title: 'Income tax (India)', icon: Icons.request_quote_rounded, route: '/tools/tax'),
    ServiceItem(title: 'Scientific calculator', icon: Icons.calculate_outlined, route: '/tools/calculator'),
    ServiceItem(title: 'Age', icon: Icons.cake_rounded, route: '/tools/age'),
    ServiceItem(title: 'Rent', icon: Icons.house_rounded, route: '/tools/rent'),
  ]),
  ServiceSection('Split and groups', subtitle: 'Share costs with other people and see who pays whom.', [
    ServiceItem(title: 'Split a bill', icon: Icons.call_split_rounded, route: '/tools/split'),
    ServiceItem(title: 'Groups and shared expenses', icon: Icons.groups_rounded, route: '/groups'),
  ]),
  ServiceSection('Reminders and bills', subtitle: 'Bill dates, EMIs, SIP days, warranty ends and rent days all raise a reminder here.', [
    ServiceItem(title: 'Reminders', icon: Icons.notifications_active_rounded, route: '/reminders'),
    ServiceItem(title: 'Budgets, goals and recurring bills', icon: Icons.event_repeat_rounded, route: '/plans'),
    ServiceItem(title: 'SIP and monthly savings', icon: Icons.trending_up_rounded, route: '/sip'),
  ]),
  ServiceSection('Credit and lending', subtitle: 'Money you have given on credit or borrowed.', [
    ServiceItem(title: 'Credit book', icon: Icons.menu_book_rounded, route: '/ledger'),
    ServiceItem(title: 'Income and spending', icon: Icons.swap_vert_rounded, route: '/entries'),
    ServiceItem(title: 'Lending and borrowing', icon: Icons.handshake_rounded, route: '/lending', needsOnline: true),
    ServiceItem(title: 'Loans and EMI tracker', icon: Icons.directions_car_rounded, route: '/loans', needsOnline: true),
    ServiceItem(title: 'Credit cards', icon: Icons.credit_card_rounded, route: '/cards', needsOnline: true),
  ]),
  ServiceSection('Cards, notes and money', subtitle: 'Everything you keep for yourself.', [
    ServiceItem(title: 'Saved cards', icon: Icons.credit_card_outlined, route: '/saved-cards'),
    ServiceItem(title: 'Passwords and notes', icon: Icons.lock_rounded, route: '/vault'),
    ServiceItem(title: 'Accounts', icon: Icons.account_balance_wallet_rounded, route: '/accounts', needsOnline: true),
    ServiceItem(title: 'Insights', icon: Icons.insights_rounded, route: '/insights', needsOnline: true),
  ]),
  ServiceSection('Security and data', subtitle: 'Keep your data safe and under your control.', [
    ServiceItem(title: 'Backup and restore', icon: Icons.backup_rounded, route: '/backup'),
    ServiceItem(title: 'App PIN and profile', icon: Icons.lock_outline_rounded, route: '/settings'),
    ServiceItem(title: 'Purchases and warranty', icon: Icons.verified_user_outlined, route: '/purchases'),
  ]),
  ServiceSection('Coming soon', subtitle: 'Planned. Each needs something outside this app before it can work.', [
    ServiceItem(title: 'Mobile recharge', icon: Icons.smartphone_rounded, note: 'Needs a licensed payment partner (BBPS or an aggregator).'),
    ServiceItem(title: 'DTH recharge', icon: Icons.tv_rounded, note: 'Needs a licensed payment partner (BBPS or an aggregator).'),
    ServiceItem(title: 'Electricity and utility bills', icon: Icons.bolt_rounded, note: 'Needs a licensed bill-payment partner (BBPS).'),
    ServiceItem(title: 'Bank account sync', icon: Icons.sync_rounded, note: 'Needs an RBI-regulated Account Aggregator partner.'),
    ServiceItem(title: 'Import bank statement', icon: Icons.upload_file_rounded, note: 'Planned: PDF or CSV import. Not built yet.'),
    ServiceItem(title: 'Send bills by email', icon: Icons.mail_outline_rounded, note: 'Needs the online version with sign-in and a mail service. Use Share for now.'),
    ServiceItem(title: 'Investments', icon: Icons.trending_up_rounded, note: 'Planned: mutual funds, fixed and recurring deposits.'),
  ]),
];

/// The Services menu, grouped by what each service is for. Features that need an account are marked in the offline build.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  String _query = '';

  /// The sections with only the tiles whose names match the search.
  List<ServiceSection> get _matching {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _sections;
    return [
      for (final s in _sections)
        if (s.items.any((i) => i.title.toLowerCase().contains(q)))
          ServiceSection(s.title, [for (final i in s.items) if (i.title.toLowerCase().contains(q)) i], subtitle: s.subtitle),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final offline = ApiConfig.offline;
    final sections = _matching;
    return Scaffold(
      appBar: AppBar(title: const Text('All services')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                offline
                    ? 'Everything here works on this phone. Tiles marked "Needs online" are part of the full version with sign-in.'
                    : 'Tap a service to open it. Tiles marked "Soon" are planned.',
                style: TextStyle(color: c.muted, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(labelText: 'Search services', prefixIcon: Icon(Icons.search_rounded)),
              ),
              if (sections.isEmpty) ...[
                const SizedBox(height: 40),
                Center(child: Text('No service matches "${_query.trim()}".', style: TextStyle(color: c.muted))),
              ],
              for (final section in sections) ...[
                const SizedBox(height: 18),
                SectionTitle(section.title),
                if (section.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(section.subtitle!, style: TextStyle(color: c.muted, fontSize: 12)),
                ],
                const SizedBox(height: 10),
                _TileGrid(
                  children: [for (final item in section.items) _ServiceTile(item: item, offline: offline)],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Every tile is the same size and sits on the same column grid in every section. The number of columns
/// follows the screen width, so a section with one tile still lines up with the rest, and nothing is stretched.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});

  final List<Widget> children;

  static const _tileWidth = 200.0;
  static const _tileHeight = 128.0;
  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    return GridView.extent(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      maxCrossAxisExtent: _tileWidth,
      mainAxisExtent: _tileHeight,
      crossAxisSpacing: _gap,
      mainAxisSpacing: _gap,
      padding: EdgeInsets.zero,
      children: children,
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.item, required this.offline});

  final ServiceItem item;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final available = item.available(offline);
    final needsOnline = item.route != null && !available;
    final badge = available ? null : (needsOnline ? 'Needs online' : 'Soon');
    return MonovaCard(
      padding: const EdgeInsets.all(12),
      onTap: () {
        if (available) {
          context.push(item.route!);
        } else {
          FormSheet.show<void>(
            context,
            title: item.title,
            child: Text(
              needsOnline
                  ? 'This needs an account, so it is part of the full MONOVA version. This offline build does not have sign-in yet.'
                  : (item.note ?? 'This is planned and not ready yet.'),
              style: const TextStyle(height: 1.45),
            ),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: available ? c.accentStart : c.border,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 20, color: available ? c.onAccent : c.muted),
              ),
              const Spacer(),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: c.warning.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(99)),
                  child: Text(badge, style: TextStyle(color: c.warning, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const Spacer(),
          // The full name is shown, wrapping onto a second line if needed, so no label is cut off.
          Text(
            item.title,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.25, color: available ? c.ink : c.muted),
          ),
        ],
      ),
    );
  }
}
/// The full list of sections, for Home's everything-in-one-place card.
List<ServiceSection> get allServiceSections => _sections;
