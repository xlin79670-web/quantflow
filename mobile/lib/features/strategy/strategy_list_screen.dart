import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/services/auth_service.dart';

final strategiesProvider = FutureProvider<List<dynamic>>((ref) async {
  final api = ref.read(apiServiceProvider);
  return await api.getStrategies();
});

class StrategyListScreen extends ConsumerWidget {
  const StrategyListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strategies = ref.watch(strategiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('策略管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => context.push('/strategy/create'),
          ),
        ],
      ),
      body: strategies.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        (strategies) {
          if (strategies.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.code_off, size: 80, color: Colors.grey[700]),
                  const SizedBox(height: 16),
                  const Text('还没有策略', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 8),
                  const Text('创建你的第一个量化策略', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => context.push('/strategy/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('手动创建'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () => _showAIGenerate(context),
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('AI 生成'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(strategiesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: strategies.length,
              itemBuilder: (_, i) => _StrategyCard(
                strategy: strategies[i],
                onTap: () => context.push('/strategy/${strategies[i]['id']}'),
                onToggle: () => _toggleStrategy(ref, strategies[i]),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAIGenerate(context),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI 生成'),
        backgroundColor: AppTheme.accentColor,
      ),
    );
  }

  void _showAIGenerate(BuildContext context) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎯 AI 策略生成', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('用自然语言描述你的交易想法，AI 自动生成策略代码', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '例如: 当 BTC 的 RSI 低于 30 且成交量放大 2 倍时买入，RSI 超过 70 卖出，止损 5%',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: 调用 AI 生成策略
                },
                icon: const Icon(Icons.auto_awesome),
                label: const Text('生成策略'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleStrategy(WidgetRef ref, Map<String, dynamic> strategy) async {
    final api = ref.read(apiServiceProvider);
    final id = strategy['id'];
    if (strategy['status'] == 'running') {
      await api.stopStrategy(id);
    } else {
      await api.startStrategy(id);
    }
    ref.invalidate(strategiesProvider);
  }
}

class _StrategyCard extends StatelessWidget {
  final Map<String, dynamic> strategy;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _StrategyCard({
    required this.strategy,
    required this.onTap,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final status = strategy['status'] ?? 'draft';
    final isRunning = status == 'running';
    final statusColor = {
      'running': AppTheme.profitColor,
      'paused': AppTheme.warningColor,
      'stopped': AppTheme.lossColor,
    }[status] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 策略图标
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isRunning ? Icons.play_arrow : Icons.code,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 策略信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(strategy['name'] ?? 'N/A',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            if (strategy['is_ai_generated'] == true) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text('AI', style: TextStyle(fontSize: 10, color: AppTheme.accentColor)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${strategy['symbol']} · ${strategy['timeframe']} · ${strategy['type']}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  // 启停按钮
                  IconButton(
                    icon: Icon(
                      isRunning ? Icons.pause_circle : Icons.play_circle,
                      color: statusColor,
                      size: 36,
                    ),
                    onPressed: onToggle,
                  ),
                ],
              ),
              if (strategy['description'] != null && strategy['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  strategy['description'],
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
