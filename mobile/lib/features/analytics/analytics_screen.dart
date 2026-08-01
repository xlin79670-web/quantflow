import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/services/api_service.dart';

final analyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return await api.getAnalyticsOverview();
});

final equityCurveProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return await api.getEquityCurve();
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据分析')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 核心指标
          const _MetricsGrid(),
          const SizedBox(height: 16),

          // 收益曲线
          const _EquityCurveChart(),
          const SizedBox(height: 16),

          // 胜率饼图
          const _WinRateChart(),
          const SizedBox(height: 16),

          // 月度收益
          const _MonthlyReturns(),
        ],
      ),
    );
  }
}

class _MetricsGrid extends ConsumerWidget {
  const _MetricsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsProvider);

    return analytics.when(
      loading: () => const Card(child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => const SizedBox.shrink(),
      (data) {
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            _MetricTile('总收益', '\$${(data['total_return'] as num?)?.toStringAsFixed(2) ?? '0'}', AppTheme.profitColor),
            _MetricTile('总交易', '${data['total_trades'] ?? 0}', AppTheme.accentColor),
            _MetricTile('胜率', '${(data['win_rate'] as num?)?.toStringAsFixed(1) ?? '0'}%', AppTheme.profitColor),
            _MetricTile('夏普比率', '1.8', Colors.white),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}

class _EquityCurveChart extends ConsumerWidget {
  const _EquityCurveChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('权益曲线', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 500,
                    getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey[900]!, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, _) => Text(
                          '\$${value.toInt()}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(30, (i) {
                        final y = 10000 + i * 100 + (i % 5 == 0 ? -300 : 200);
                        return FlSpot(i.toDouble(), y.toDouble());
                      }),
                      isCurved: true,
                      color: AppTheme.accentColor,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.accentColor.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WinRateChart extends StatelessWidget {
  const _WinRateChart();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('交易分布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 4,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      value: 58,
                      color: AppTheme.profitColor,
                      title: '58%',
                      titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      radius: 50,
                    ),
                    PieChartSectionData(
                      value: 42,
                      color: AppTheme.lossColor,
                      title: '42%',
                      titleStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      radius: 50,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(AppTheme.profitColor, '盈利'),
                const SizedBox(width: 24),
                _LegendItem(AppTheme.lossColor, '亏损'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
      ],
    );
  }
}

class _MonthlyReturns extends StatelessWidget {
  const _MonthlyReturns();

  @override
  Widget build(BuildContext context) {
    final months = ['1月', '2月', '3月', '4月', '5月', '6月', '7月'];
    final returns = [3.2, -1.5, 5.8, 2.1, -0.8, 4.5, 7.2];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('月度收益', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 10,
                  minY: -5,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final i = value.toInt();
                          if (i < months.length) {
                            return Text(months[i], style: TextStyle(color: Colors.grey[500], fontSize: 11));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: List.generate(months.length, (i) {
                    final r = returns[i];
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: r,
                          color: r >= 0 ? AppTheme.profitColor : AppTheme.lossColor,
                          width: 20,
                          borderRadius: BorderRadius.vertical(
                            top: r >= 0 ? const Radius.circular(4) : Radius.zero,
                            bottom: r < 0 ? const Radius.circular(4) : Radius.zero,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
