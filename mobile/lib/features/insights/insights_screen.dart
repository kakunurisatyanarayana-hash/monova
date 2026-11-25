import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../state/providers.dart';

/// Monthly income and expense report, category breakdown and net-worth history. Everything is computed from stored records.
class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  late ({int year, int month}) _period = (year: DateTime.now().year, month: DateTime.now().month);

  void _shift(int delta) {
    final d = DateTime(_period.year, _period.month + delta);
    setState(() => _period = (year: d.year, month: d.month));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final report = ref.watch(monthlyReportProvider(_period));
    final history = ref.watch(netWorthHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monthlyReportProvider(_period));
          ref.invalidate(netWorthHistoryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () => _shift(-1), icon: const Icon(Icons.chevron_left_rounded)),
                Text(monthLabel(_period.year, _period.month), style: Theme.of(context).textTheme.titleMedium),
                IconButton(onPressed: () => _shift(1), icon: const Icon(Icons.chevron_right_rounded)),
              ],
            ),
            report.when(
              loading: () => const LoadingBox(),
              error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(monthlyReportProvider(_period))),
              data: (r) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: _Metric(label: 'Income', value: money(r.income), tone: AmountTone.income)),
                      const SizedBox(width: 12),
                      Expanded(child: _Metric(label: 'Expenses', value: money(r.expenses), tone: AmountTone.expense)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MonovaCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Left over', style: TextStyle(color: c.muted, fontSize: 12)),
                              AmountText(money(r.net), tone: r.net >= 0 ? AmountTone.income : AmountTone.expense, size: 18),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Savings rate', style: TextStyle(color: c.muted, fontSize: 12)),
                            Text('${r.savingsRate.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (r.groupShare > 0 || r.interest > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Includes ${money(r.groupShare)} of your group shares and ${money(r.interest)} of loan and debt interest.',
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const SectionTitle('Spending by category'),
                  const SizedBox(height: 8),
                  MonovaCard(child: _CategoryPie(items: r.categories)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionTitle('Net worth · last 12 months'),
            const SizedBox(height: 8),
            MonovaCard(
              child: SizedBox(
                height: 200,
                child: history.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ErrorState(error: e, onRetry: () => ref.invalidate(netWorthHistoryProvider)),
                  data: (points) => points.isEmpty
                      ? Center(child: Text('Not enough history yet.', style: TextStyle(color: c.muted)))
                      : _NetWorthLine(points: points),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(label: const Text('Budgets & savings'), onPressed: () => context.push('/planning')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.tone});

  final String label;
  final String value;
  final AmountTone tone;

  @override
  Widget build(BuildContext context) {
    return MonovaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: context.monova.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: AmountText(value, tone: tone, size: 20)),
        ],
      ),
    );
  }
}

class _CategoryPie extends StatelessWidget {
  const _CategoryPie({required this.items});

  final List<CategoryTotal> items;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    if (items.isEmpty) return Text('No spending recorded for this month.', style: TextStyle(color: c.muted));
    final palette = [c.accentStart, c.accentEnd, c.income, c.warning, c.expense, c.muted];
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 46,
              sections: [
                for (var i = 0; i < items.length && i < 6; i++)
                  PieChartSectionData(
                    value: items[i].amount,
                    color: palette[i % palette.length],
                    radius: 26,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < items.length && i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: palette[i % palette.length], shape: BoxShape.circle)),
                const SizedBox(width: 10),
                Expanded(child: Text(items[i].name)),
                Text('${items[i].percent.toStringAsFixed(0)}%', style: TextStyle(color: c.muted)),
                const SizedBox(width: 12),
                Text(money(items[i].amount), style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }
}

class _NetWorthLine extends StatelessWidget {
  const _NetWorthLine({required this.points});

  final List<NetWorthPoint> points;

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    final spots = [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].netWorth)];
    final values = points.map((p) => p.netWorth);
    final minY = values.reduce((a, b) => a < b ? a : b);
    final maxY = values.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY).abs() * 0.15) + 1;
    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => FlLine(color: c.border, strokeWidth: 1)),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: 3,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Text(monthLabel(points[i].asOf.year, points[i].asOf.month).substring(0, 3), style: TextStyle(color: c.muted, fontSize: 11));
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            gradient: c.aurora,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.accentStart.withValues(alpha: 0.25), Colors.transparent])),
          ),
        ],
      ),
    );
  }
}
