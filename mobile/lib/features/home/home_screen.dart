import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'all_features.dart';
import 'attention_card.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/profile_store.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';
import '../tools/bill_balance_card.dart';
import 'recent_activity_card.dart';
import 'money_overview_card.dart';
import '../tools/tools_screens.dart';

/// Home: the daily answer to "where do I stand?" The Halo shows liquid cash at the centre, card use on the inner ring,
/// receivables (green) and payables (rose) on the outer ring. Every figure comes from the server dashboard.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(sessionProvider).isSignedIn) return const _GuestHome();
    final dashboard = ref.watch(dashboardProvider);
    final user = ref.watch(sessionProvider).user;
    final c = context.monova;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(dashboardProvider.future),
        child: dashboard.when(
          loading: () => const _HomeSkeleton(),
          error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(dashboardProvider)),
          data: (d) => ListView(
            padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 96),
            children: [
              _Header(name: user?.displayName ?? 'there'),
              const SizedBox(height: 16),
              Center(child: _Halo(d: d)),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: c.raised, borderRadius: BorderRadius.circular(99), border: Border.all(color: c.border)),
                  child: Text('Net worth ${money(d.netWorth)}', style: TextStyle(color: d.netWorth >= 0 ? c.income : c.expense, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _Kpi(label: 'Income · ${monthLabel(d.budget.year, d.budget.month)}', value: money(d.monthIncome), tone: AmountTone.income)),
                  const SizedBox(width: 12),
                  Expanded(child: _Kpi(label: 'Spent this month', value: money(d.monthExpenses), tone: AmountTone.expense)),
                ],
              ),
              const SizedBox(height: 20),
              SectionTitle('Cards', action: 'See all', onAction: () => context.push('/cards')),
              const SizedBox(height: 8),
              if (d.cardLimit > 0) _CardStrip(onOpen: () => context.push('/cards')),
              if (d.cardLimit == 0)
                MonovaCard(
                  onTap: () => context.push('/cards'),
                  child: const Text('Add a credit card to track limits, bills and due dates.'),
                ),
              const SizedBox(height: 20),
              SectionTitle('Due soon'),
              const SizedBox(height: 8),
              if (d.upcoming.isEmpty)
                MonovaCard(child: Text('Nothing due in the next 30 days.', style: TextStyle(color: c.muted)))
              else
                MonovaCard(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(children: [for (final u in d.upcoming.take(5)) _UpcomingRow(item: u)]),
                ),
              const SizedBox(height: 20),
              SectionTitle('Spending · last 6 months'),
              const SizedBox(height: 8),
              MonovaCard(child: SizedBox(height: 170, child: _TrendChart(points: d.trend))),
              const SizedBox(height: 20),
              SectionTitle('Where it went', action: 'Insights', onAction: () => context.go('/insights')),
              const SizedBox(height: 8),
              MonovaCard(child: _CategoryBars(items: d.categories)),
              const SizedBox(height: 20),
              SectionTitle('Budget', action: 'Plan', onAction: () => context.push('/planning')),
              const SizedBox(height: 8),
              _BudgetCard(budget: d.budget),
              const SizedBox(height: 20),
              SectionTitle('Recent', action: 'Activity', onAction: () => context.go('/activity')),
              const SizedBox(height: 8),
              if (d.recent.isEmpty)
                const EmptyState(icon: Icons.receipt_long_rounded, title: 'No activity yet', message: 'Tap + to record your first expense or income.')
              else
                MonovaCard(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [for (final r in d.recent) _RecentRow(item: r)]),
                ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(label: const Text('Accounts'), onPressed: () => context.push('/accounts')),
                  ActionChip(label: const Text('Credit manager'), onPressed: () => context.push('/lending')),
                  ActionChip(label: const Text('Loans & EMI'), onPressed: () => context.push('/loans')),
                  ActionChip(label: const Text('Savings goals'), onPressed: () => context.push('/planning')),
                  ActionChip(label: const Text('Property and rooms'), onPressed: () => context.push('/property')),
                  ActionChip(label: const Text('Calculators & bill split'), onPressed: () => context.push('/tools')),
                  ActionChip(label: const Text('All services'), onPressed: () => context.push('/services')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final first = name.split(' ').first;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dayLabel(DateTime.now()), style: TextStyle(color: c.muted, fontWeight: FontWeight.w600)),
              Text('$greeting, $first', style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
          icon: CircleAvatar(
            radius: 18,
            backgroundColor: c.raised,
            child: Text(first.isEmpty ? '?' : first[0].toUpperCase(), style: TextStyle(color: c.ink, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}

class _Halo extends StatelessWidget {
  const _Halo({required this.d});

  final Dashboard d;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(260, 260),
            painter: _HaloPainter(
              cardUse: d.cardLimit <= 0 ? 0 : (d.cardOutstanding / d.cardLimit).clamp(0.0, 1.0),
              receivable: d.groupOwedToYou + d.receivablesOutstanding,
              payable: d.groupYouOwe + d.debtsOutstanding + d.loansOutstanding,
              track: c.border,
              income: c.income,
              expense: c.expense,
              accentA: c.accentStart,
              accentB: c.accentEnd,
              background: c.raised,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Liquid cash', style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              const SizedBox(height: 2),
              Text(
                moneyCompact(d.totalLiquid),
                style: TextStyle(color: c.ink, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              Text(
                'Receivable ${moneyCompact(d.groupOwedToYou + d.receivablesOutstanding)}',
                style: TextStyle(color: c.income, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              Text(
                'Payable ${moneyCompact(d.groupYouOwe + d.debtsOutstanding + d.loansOutstanding)}',
                style: TextStyle(color: c.expense, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({
    required this.cardUse,
    required this.receivable,
    required this.payable,
    required this.track,
    required this.income,
    required this.expense,
    required this.accentA,
    required this.accentB,
    required this.background,
  });

  final double cardUse;
  final double receivable;
  final double payable;
  final Color track;
  final Color income;
  final Color expense;
  final Color accentA;
  final Color accentB;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = math.min(size.width, size.height) / 2 - 8;
    final stroke = 14.0;

    canvas.drawCircle(center, outer, Paint()..color = background);

    final total = receivable + payable;
    final receivableShare = total <= 0 ? 0.5 : receivable / total;
    // Outer ring: receivables on the top half, payables on the bottom half, with a gap between them.
    final trackPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..color = track..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, outer, trackPaint);

    final arcPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = stroke..strokeCap = StrokeCap.round;
    const gap = 0.06;
    final full = math.pi * 2 - gap * 2;
    final startAngle = -math.pi / 2 + gap;
    final recvSweep = full * receivableShare;
    final paySweep = full - recvSweep;
    if (total > 0) {
      arcPaint.color = income;
      canvas.drawArc(Rect.fromCircle(center: center, radius: outer), startAngle, recvSweep, false, arcPaint);
      arcPaint.color = expense;
      canvas.drawArc(Rect.fromCircle(center: center, radius: outer), startAngle + recvSweep + gap, paySweep, false, arcPaint);
    }

    // Inner ring: credit card utilisation as a gradient arc.
    final innerR = outer - 30;
    canvas.drawCircle(center, innerR, Paint()..style = PaintingStyle.stroke..strokeWidth = 8..color = track);
    final sweepRect = Rect.fromCircle(center: center, radius: innerR);
    final cardPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(colors: [accentA, accentB, accentA], startAngle: -math.pi / 2, endAngle: 3 * math.pi / 2).createShader(sweepRect);
    canvas.drawArc(sweepRect, -math.pi / 2, math.pi * 2 * cardUse.clamp(0.0, 1.0), false, cardPaint);
  }

  @override
  bool shouldRepaint(covariant _HaloPainter old) =>
      old.cardUse != cardUse || old.receivable != receivable || old.payable != payable || old.track != track;
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final AmountTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return MonovaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: AmountText(value, tone: tone, size: 20)),
        ],
      ),
    );
  }
}

class _CardStrip extends ConsumerWidget {
  const _CardStrip({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(cardsProvider);
    final c = context.monova;
    return cards.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) => SizedBox(
        height: 124,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final card = list[i];
            final warn = card.utilizationPercent >= 70;
            return SizedBox(
              width: 230,
              child: MonovaCard(
                onTap: onOpen,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [c.raised, c.border],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${card.name}  ••${card.last4}', style: TextStyle(color: c.ink, fontWeight: FontWeight.w700)),
                    ProgressBar(value: card.utilizationPercent, color: warn ? c.warning : c.accentStart),
                    Text(
                      '${card.utilizationPercent.toStringAsFixed(0)}% used · due ${dayShort(card.nextDueDate)}',
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.item});

  final UpcomingItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final incoming = item.isIncoming;
    return ListTile(
      leading: Icon(incoming ? Icons.south_west_rounded : Icons.north_east_rounded, color: incoming ? c.income : c.warning),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${item.kind} · ${relativeDay(item.dueOn)}', style: TextStyle(color: c.muted)),
      trailing: AmountText(money(item.amount), tone: incoming ? AmountTone.income : AmountTone.neutral, size: 14),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.item});

  final RecentItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final isIncome = item.type == 'Income';
    final isRefund = item.type == 'Refund';
    final tone = isIncome || isRefund ? AmountTone.income : AmountTone.neutral;
    final signed = isIncome || isRefund ? '+${money(item.amount)}' : '−${money(item.amount)}';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: c.border,
        child: Icon(isIncome ? Icons.trending_up_rounded : Icons.shopping_bag_outlined, color: c.ink, size: 18),
      ),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${item.categoryName ?? item.type} · ${relativeDay(item.date)}', style: TextStyle(color: c.muted)),
      trailing: AmountText(signed, tone: tone, size: 14),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.points});

  final List<MonthPoint> points;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    if (points.isEmpty) return const SizedBox.shrink();
    final maxY = points.map((p) => math.max(p.expenses, p.income)).fold<double>(0, math.max);
    return BarChart(
      BarChartData(
        maxY: maxY <= 0 ? 1000 : maxY * 1.2,
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(names[points[i].month - 1], style: TextStyle(color: c.muted, fontSize: 11)),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < points.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: points[i].expenses,
                width: 14,
                borderRadius: BorderRadius.circular(6),
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [c.accentEnd, c.accentStart]),
              ),
            ]),
        ],
      ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  const _CategoryBars({required this.items});

  final List<CategoryTotal> items;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    if (items.isEmpty) return Text('No spending recorded this month.', style: TextStyle(color: c.muted));
    return Column(
      children: [
        for (final item in items.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('${item.percent.toStringAsFixed(0)}%', style: TextStyle(color: c.muted)),
                    const SizedBox(width: 12),
                    Text(money(item.amount), style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressBar(value: item.percent),
              ],
            ),
          ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({required this.budget});

  final BudgetSummary budget;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    if (budget.overallBudget <= 0) {
      return MonovaCard(
        onTap: () => context.push('/planning'),
        child: Text('Set a monthly budget to see how much room you have left.', style: TextStyle(color: c.muted)),
      );
    }
    final color = budget.overallStatus == 'Over' ? c.expense : (budget.overallStatus == 'Warning' ? c.warning : c.accentStart);
    return MonovaCard(
      onTap: () => context.push('/planning'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('${money(budget.overallSpent)} of ${money(budget.overallBudget)}', style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('${budget.overallPercentUsed.toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          ProgressBar(value: budget.overallPercentUsed, color: color),
          for (final w in budget.warnings.take(2)) ...[
            const SizedBox(height: 10),
            Text(w, style: TextStyle(color: c.warning, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

/// Home for guests: the free tools are front and centre, and signing in is an invitation, not a gate.
class _GuestHome extends StatelessWidget {
  const _GuestHome();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 96),
        children: [
          const _HomeHero(),
          const SizedBox(height: 16),
          const AttentionCard(),
          const SizedBox(height: 14),
          const _QuickActions(),
          const SizedBox(height: 20),
          const MoneyOverviewCard(),
          const SizedBox(height: 14),
          const RecentActivityCard(),
          const SizedBox(height: 14),
          const BillBalanceCard(),
          const SizedBox(height: 22),
          const AllFeaturesCard(),
          const SizedBox(height: 22),
          SectionTitle('Free tools', action: 'All services', onAction: () => context.push('/services')),
          const SizedBox(height: 10),
          const _FreeToolsGrid(),
          const SizedBox(height: 22),
          // The offline build has no accounts, so the sign-in prompt is hidden there.
          if (!ApiConfig.offline) const SignInGate(
            title: 'Track everything in one place',
            message: 'Accounts, credit cards, groups, loans, budgets and insights sync to your account. Create one in under a minute.',
            actionLabel: 'Create account or sign in',
          ),
        ],
      ),
    );
  }
}

/// The top of the home page: the wordmark, a glowing panel, and the greeting.
class _HomeHero extends StatelessWidget {
  const _HomeHero();

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        gradient: c.hero,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: c.accentStart.withValues(alpha: 0.25), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MONOVA', style: TextStyle(color: c.onAccent.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2.5)),
          const SizedBox(height: 14),
          ProfileGreeting(color: c.onAccent),
          const SizedBox(height: 6),
          Text(
            'Your money, your records, on this phone.',
            style: TextStyle(color: c.onAccent.withValues(alpha: 0.9), fontSize: 14, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Four one-tap shortcuts, styled like the action row in banking apps.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ActionCircle(icon: Icons.call_split_rounded, label: 'Split', onTap: () => context.push('/tools/split')),
        _ActionCircle(icon: Icons.menu_book_rounded, label: 'Customers', onTap: () => context.push('/ledger')),
        _ActionCircle(icon: Icons.lock_rounded, label: 'Vault', onTap: () => context.push('/vault-hub')),
      ],
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    // The ripple belongs to the circle only, so it centres on the icon and does not spread over the label.
    return Column(
      children: [
        // Material owns the circle and its ripple, so the background is always painted where the layout puts it.
        Material(
          color: c.accentStart.withValues(alpha: 0.14),
          shape: CircleBorder(side: BorderSide(color: c.accentStart.withValues(alpha: 0.35))),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 62,
              height: 62,
              child: Center(child: Icon(icon, color: c.accentStart, size: 26)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: c.ink, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
/// Every free tool on one page, so people do not have to search for them in All services.
class _FreeToolsGrid extends StatelessWidget {
  const _FreeToolsGrid();

  static const _tools = [
    (icon: Icons.calculate_rounded, label: 'EMI', route: '/tools/emi'),
    (icon: Icons.percent_rounded, label: 'Interest', route: '/tools/interest'),
    (icon: Icons.receipt_long_rounded, label: 'GST', route: '/tools/gst'),
    (icon: Icons.request_quote_rounded, label: 'Income tax', route: '/tools/tax'),
    (icon: Icons.call_split_rounded, label: 'Split a bill', route: '/tools/split'),
    (icon: Icons.calculate_outlined, label: 'Scientific', route: '/tools/calculator'),
    (icon: Icons.cake_rounded, label: 'Age', route: '/tools/age'),
    (icon: Icons.house_rounded, label: 'Rent', route: '/tools/rent'),
  ];

  @override
  Widget build(BuildContext context) {
    return EqualTileGrid(
      minTileWidth: 120,
      tileHeight: 96,
      children: [
        for (final t in _tools) _ToolCard(icon: t.icon, label: t.label, onTap: () => context.push(t.route)),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    return MonovaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      child: Column(
        children: [
          Icon(icon, color: c.accentStart, size: 28),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

/// "Hello, Name" on the home page, from the profile set on first open.
class ProfileGreeting extends ConsumerWidget {
  const ProfileGreeting({super.key, this.color});

  /// Text colour. Defaults to the normal ink; the hero passes a light colour for its dark background.
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.monova;
    final name = ref.watch(profileProvider).profile?.name ?? '';
    if (name.isEmpty) return const SizedBox.shrink();
    return Text('Hello, $name', style: TextStyle(color: color ?? c.ink, fontSize: 18, fontWeight: FontWeight.w700));
  }
}