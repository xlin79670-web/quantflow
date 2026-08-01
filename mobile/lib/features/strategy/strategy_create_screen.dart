import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/services/api_service.dart';

class StrategyCreateScreen extends ConsumerStatefulWidget {
  const StrategyCreateScreen({super.key});

  @override
  ConsumerState<StrategyCreateScreen> createState() => _StrategyCreateScreenState();
}

class _StrategyCreateScreenState extends ConsumerState<StrategyCreateScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedSymbol = 'BTCUSDT';
  String _selectedTimeframe = '1h';
  String _selectedType = 'ma_cross';
  bool _isAIGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('创建策略')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 模式选择
          Row(
            children: [
              Expanded(
                child: _ModeCard(
                  icon: Icons.auto_awesome,
                  title: 'AI 生成',
                  subtitle: '用自然语言描述',
                  color: const Color(0xFF00D2D3),
                  onTap: _showAIGenerate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ModeCard(
                  icon: Icons.code,
                  title: '手动创建',
                  subtitle: '选择模板配置',
                  color: const Color(0xFF6C5CE7),
                  onTap: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // 策略名称
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '策略名称', hintText: '例如: BTC 均线交叉'),
          ),
          const SizedBox(height: 16),

          // 策略描述
          TextField(
            controller: _descController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '策略描述（可选）'),
          ),
          const SizedBox(height: 16),

          // 交易对
          DropdownButtonFormField<String>(
            value: _selectedSymbol,
            decoration: const InputDecoration(labelText: '交易对'),
            items: ['BTCUSDT', 'ETHUSDT', 'BNBUSDT', 'SOLUSDT'].map((s) {
              return DropdownMenuItem(value: s, child: Text(s));
            }).toList(),
            onChanged: (v) => setState(() => _selectedSymbol = v!),
          ),
          const SizedBox(height: 16),

          // 时间周期
          DropdownButtonFormField<String>(
            value: _selectedTimeframe,
            decoration: const InputDecoration(labelText: '时间周期'),
            items: ['1m', '5m', '15m', '1h', '4h', '1d'].map((s) {
              return DropdownMenuItem(value: s, child: Text(s));
            }).toList(),
            onChanged: (v) => setState(() => _selectedTimeframe = v!),
          ),
          const SizedBox(height: 16),

          // 策略类型
          DropdownButtonFormField<String>(
            value: _selectedType,
            decoration: const InputDecoration(labelText: '策略类型'),
            items: const [
              DropdownMenuItem(value: 'ma_cross', child: Text('均线交叉')),
              DropdownMenuItem(value: 'rsi', child: Text('RSI 超买超卖')),
              DropdownMenuItem(value: 'grid', child: Text('网格交易')),
              DropdownMenuItem(value: 'custom', child: Text('自定义')),
            ],
            onChanged: (v) => setState(() => _selectedType = v!),
          ),
          const SizedBox(height: 32),

          // 创建按钮
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _createStrategy,
              icon: const Icon(Icons.add),
              label: const Text('创建策略', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAIGenerate() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎯 AI 生成策略'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('用自然语言描述你的交易想法，AI 会自动生成策略代码。'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '例如: 当 BTC 的 RSI 低于 30 且成交量放大 2 倍时买入，\nRSI 超过 70 卖出，止损 5%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isAIGenerating = true);
              try {
                final api = ref.read(apiServiceProvider);
                final result = await api.aiGenerateStrategy(controller.text);
                _nameController.text = result['name'] ?? 'AI 策略';
                _descController.text = result['description'] ?? '';
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ 策略已生成'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('生成失败: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                setState(() => _isAIGenerating = false);
              }
            },
            child: const Text('生成'),
          ),
        ],
      ),
    );
  }

  Future<void> _createStrategy() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入策略名称')));
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.createStrategy({
        'name': _nameController.text,
        'description': _descController.text,
        'type': _selectedType,
        'symbol': _selectedSymbol,
        'timeframe': _selectedTimeframe,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ 策略创建成功'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 36, color: color),
              const SizedBox(height: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }
}
