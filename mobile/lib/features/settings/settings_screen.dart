import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/services/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          // 账户
          const _SectionHeader('账户'),
          ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: const Text('个人资料'),
            subtitle: const Text('user@example.com'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.key),
            title: const Text('交易所账户'),
            subtitle: const Text('管理 API Key'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          const Divider(),

          // AI 设置
          const _SectionHeader('AI 设置'),
          SwitchListTile(
            secondary: const Icon(Icons.auto_awesome),
            title: const Text('AI 市场分析'),
            subtitle: const Text('自动分析新闻和市场情绪'),
            value: true,
            onChanged: (v) {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.psychology),
            title: const Text('策略自进化'),
            subtitle: const Text('AI 自动优化策略参数'),
            value: false,
            onChanged: (v) {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.shield),
            title: const Text('AI 风险预警'),
            subtitle: const Text('高风险时自动暂停策略'),
            value: true,
            onChanged: (v) {},
          ),

          const Divider(),

          // 通知
          const _SectionHeader('通知'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('交易通知'),
            subtitle: const Text('开仓/平仓/止损触发时通知'),
            value: true,
            onChanged: (v) {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.warning),
            title: const Text('风险告警'),
            subtitle: const Text('异常波动和风险预警'),
            value: true,
            onChanged: (v) {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.summarize),
            title: const Text('每日报告'),
            subtitle: const Text('每日收益和策略表现汇总'),
            value: false,
            onChanged: (v) {},
          ),

          const Divider(),

          // 安全
          const _SectionHeader('安全'),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('生物识别'),
            subtitle: const Text('使用指纹或 Face ID 登录'),
            value: false,
            onChanged: (v) {},
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('修改密码'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          const Divider(),

          // 关于
          const _SectionHeader('关于'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('版本'),
            trailing: const Text('v1.0.0', style: TextStyle(color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('用户协议'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('隐私政策'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),

          const Divider(),

          // 退出登录
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认退出'),
                    content: const Text('确定要退出登录吗？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('退出', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await ref.read(authStateProvider.notifier).logout();
                }
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('退出登录', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey[500],
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
