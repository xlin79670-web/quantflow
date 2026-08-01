import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/services/auth_service.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuantFlow', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push('/settings')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardDataProvider),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 总览卡片
            const _OverviewCard(),
            const SizedBox(height: 16),

            // 收益曲线
            const _EquityCurveCard(),
            const SizedBox(height: 16),

            // 策略状态
            Row(
              children: [
                const Text('策略状态', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(onPressed: () => context.go('/strategy'), child: const Text('查看全部')),
              ],
            ),
            const SizedBox(height: 8),
            const _StrategyStatusList(),
            const SizedBox(height: 16),

            // 最近交易
            Row(
              children: [
                const Text('最近交易', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(onPressed: () => context.go('/trading'), child: const Text('查看全部')),
              ],
            ),
            const SizedBox(height: 8),
            const _RecentTradesList(),
          ],
        ),
      ),
    );
  }
}

// ==================== 数据 Provider ====================

final dashboardDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  final results = await Future.wait([
    api.getAnalyticsOverview(),
    api.getStrategies(),
    api.getTrades(),
    api.getTicker('BTCUSDT'),
  ]);
  return {
    'overview': results[0],
    'strategies': results[1],
    'trades': results[2],
    'ticker': results[3],
  };
});

// ==================== 总览卡片 ====================

class _OverviewCard extends ConsumerWidget {
  const _OverviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardDataProvider);

    return data.when(
      loading: () => const Card(child: SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => Card(child: SizedBox(height: 160, child: Center(child: Text('加载失败: $e')))),
      data: (data) {
        final overview = data['overview'] as Map<String, dynamic>? ?? {};
        final ticker = data['ticker'] as Map<String, dynamic>? ?? {};
        final totalReturn = (overview['total_return'] as num?)?.toDouble() ?? 0;
        final isProfit = totalReturn >= 0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('总资产', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '\$${(10000 + totalReturn).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('今日收益', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '${isProfit ? '+' : ''}${totalReturn.toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isProfit ? AppTheme.profitColor : AppTheme.lossColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatItem('BTC', '\$${(ticker['price'] as num?)?.toStringAsFixed(0) ?? '---'}'),
                    _StatItem('24h涨跌', '${(ticker['change_24h'] as num?)?.toStringAsFixed(2) ?? '---'}%'),
                    _StatItem('胜率', '${(overview['win_rate'] as num?)?.toStringAsFixed(1) ?? '---'}%'),
                    _StatItem('总交易', '${overview['total_trades'] ?? 0}'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ==================== 收益曲线 ====================

class _EquityCurveCard extends ConsumerWidget {
  const _EquityCurveCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('收益曲线', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _mockEquityData(),
                      isCurved: true,
                      color: AppTheme.accentColor,
                      barWidth: 2.5,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.accentColor.withOpacity(0.1),
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

  List<FlSpot> _mockEquityData() {
    // 模拟数据，实际从 API 获取
    return [
      const FlSpot(0, 10000), const FlSpot(1, 10150), const FlSpot(2, 10080),
      const FlSpot(3, 10300), const FlSpot(4, 10250), const FlSpot(5, 10500),
      const FlSpot(6, 10420), const FlSpot(7, 10680), const FlSpot(8, 10600),
      const FlSpot(9, 10850), const FlSpot(10, 10750), const FlSpot(11, 11000),
    ];
  }
}

// ==================== 策略状态列表 ====================

class _StrategyStatusList extends ConsumerWidget {
  const _StrategyStatusList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardDataProvider);

    return data.when(
      loading: () => const Card(child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => const SizedBox.shrink(),
      data: (data) {
        final strategies = (data['strategies'] as List?)?.take(3).toList() ?? [];
        if (strategies.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(Icons.code_off, size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  const Text('还没有策略'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/strategy/create'),
                    icon: const Icon(Icons.add),
                    label: const Text('创建策略'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: strategies.map<Widget>((s) {
            final status = s['status'] ?? 'draft';
            final statusColor = {
              'running': AppTheme.profitColor,
              'paused': AppTheme.warningColor,
              'stopped': AppTheme.lossColor,
            }[status] ?? Colors.grey;

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.2),
                  child: Icon(
                    status == 'running' ? Icons.play_arrow : status == 'paused' ? Icons.pause : Icons.stop,
                    color: statusColor,
                  ),
                ),
                title: Text(s['name'] ?? 'N/A'),
                subtitle: Text('${s['symbol']} · ${s['timeframe']} · ${s['type']}'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(status, style: TextStyle(color: statusColor, fontSize: 12)),
                ),
                onTap: () => context.push('/strategy/${s['id']}'),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ==================== 最近交易 ====================

class _RecentTradesList extends ConsumerWidget {
  const _RecentTradesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardDataProvider);

    return data.when(
      loading: () => const Card(child: SizedBox(height: 100, child: Center(child: CircularProgressIndicator()))),
      error: (e, _) => const SizedBox.shrink(),
      data: (data) {
        final trades = (data['trades'] as List?)?.take(5).toList() ?? [];
        if (trades.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('暂无交易记录', style: TextStyle(color: Colors.grey))),
            ),
          );
        }

        return Column(
          children: trades.map<Widget>((t) {
            final pnl = (t['pnl'] as num?)?.toDouble();
            final isProfit = pnl != null && pnl >= 0;

            return Card(
              child: ListTile(
                leading: Icon(
                  t['side'] == 'buy' ? Icons.arrow_downward : Icons.arrow_upward,
                  color: t['side'] == 'buy' ? AppTheme.profitColor : AppTheme.lossColor,
                ),
                title: Text('${t['symbol']} ${t['side']?.toString().toUpperCase()}'),
                subtitle: Text('价格: ${t['price']} · 数量: ${t['quantity']}'),
                trailing: pnl != null
                    ? Text(
                        '${isProfit ? '+' : ''}${pnl.toStringAsFixed(2)}%',
                        style: TextStyle(
                          color: isProfit ? AppTheme.profitColor : AppTheme.lossColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : const Text('--', style: TextStyle(color: Colors.grey)),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
