import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/services/auth_service.dart';

final positionsProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return await api.getPositions();
});

final tradesProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return await api.getTrades();
});

class TradingScreen extends ConsumerWidget {
  const TradingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('交易'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '持仓', icon: Icon(Icons.account_balance_wallet_outlined)),
              Tab(text: '历史', icon: Icon(Icons.history)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _PositionsTab(),
            _TradesHistoryTab(),
          ],
        ),
      ),
    );
  }
}

class _PositionsTab extends ConsumerWidget {
  const _PositionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positions = ref.watch(positionsProvider);

    return positions.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (positions) {
        if (positions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('暂无持仓', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(positionsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: positions.length,
            itemBuilder: (_, i) {
              final pos = positions[i];
              final pnl = (pos['pnl'] as num?)?.toDouble() ?? 0;
              final isProfit = pnl >= 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: pos['side'] == 'long'
                                  ? AppTheme.profitColor.withOpacity(0.15)
                                  : AppTheme.lossColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pos['side']?.toString().toUpperCase() ?? 'N/A',
                              style: TextStyle(
                                color: pos['side'] == 'long' ? AppTheme.profitColor : AppTheme.lossColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(pos['symbol'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text(
                            '${isProfit ? '+' : ''}${pnl.toStringAsFixed(2)}%',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isProfit ? AppTheme.profitColor : AppTheme.lossColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _PositionDetail('入场价', '\$${pos['entry_price']}'),
                          _PositionDetail('当前价', '\$${pos['mark_price']}'),
                          _PositionDetail('数量', '${pos['quantity']}'),
                          _PositionDetail('盈亏', '\$${(pos['pnl'] as num?)?.toStringAsFixed(2) ?? '0'}'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PositionDetail extends StatelessWidget {
  final String label;
  final String value;
  const _PositionDetail(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

class _TradesHistoryTab extends ConsumerWidget {
  const _TradesHistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trades = ref.watch(tradesProvider);

    return trades.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (trades) {
        if (trades.isEmpty) {
          return const Center(child: Text('暂无交易记录', style: TextStyle(color: Colors.grey)));
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(tradesProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: trades.length,
            itemBuilder: (_, i) {
              final t = trades[i];
              final pnl = (t['pnl'] as num?)?.toDouble();
              final isProfit = pnl != null && pnl >= 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (t['side'] == 'buy' ? AppTheme.profitColor : AppTheme.lossColor).withOpacity(0.15),
                    child: Icon(
                      t['side'] == 'buy' ? Icons.arrow_downward : Icons.arrow_upward,
                      color: t['side'] == 'buy' ? AppTheme.profitColor : AppTheme.lossColor,
                    ),
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
                      : const Text('--'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
