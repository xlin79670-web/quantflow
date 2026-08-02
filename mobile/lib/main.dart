import 'package:flutter/material.dart';

void main() => runApp(const QuantFlowApp());

class QuantFlowApp extends StatelessWidget {
  const QuantFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QuantFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6C5CE7),
          secondary: const Color(0xFF00D2D3),
          surface: const Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F23),
        cardColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F23),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const MainShell(),
    );
  }
}

// ==================== 主界面 ====================

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = const [
    DashboardPage(),
    StrategyPage(),
    TradingPage(),
    AIChatPage(),
    AnalyticsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: const Color(0xFF1A1A2E),
        indicatorColor: const Color(0xFF6C5CE7).withOpacity(0.3),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: '仪表盘'),
          NavigationDestination(icon: Icon(Icons.code_outlined), selectedIcon: Icon(Icons.code), label: '策略'),
          NavigationDestination(icon: Icon(Icons.candlestick_chart_outlined), selectedIcon: Icon(Icons.candlestick_chart), label: '交易'),
          NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'AI'),
          NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics), label: '分析'),
        ],
      ),
    );
  }
}

// ==================== 仪表盘 ====================

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuantFlow', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 总览卡片
          Card(
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
                          const Text('\$10,000.00', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('今日收益', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                          const SizedBox(height: 4),
                          const Text('+2.5%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00B894))),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _statItem('BTC', '\$62,450'),
                      _statItem('24h', '-1.2%'),
                      _statItem('胜率', '58%'),
                      _statItem('交易', '24'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 收益曲线
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('收益曲线', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: CustomPaint(
                      size: const Size(double.infinity, 180),
                      painter: _EquityCurvePainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 策略状态
          const Text('策略状态', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _strategyCard('均线交叉策略', 'BTCUSDT · 1h', 'running', '+12.5%'),
          _strategyCard('RSI 反转策略', 'ETHUSDT · 4h', 'paused', '+8.3%'),
          _strategyCard('布林带回归', 'BTCUSDT · 15m', 'stopped', '-2.1%'),
          const SizedBox(height: 16),

          // 最近交易
          const Text('最近交易', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _tradeItem('BTCUSDT', 'BUY', '62,450', '+3.2%', true),
          _tradeItem('ETHUSDT', 'SELL', '3,120', '-1.5%', false),
          _tradeItem('BTCUSDT', 'BUY', '61,800', '+5.1%', true),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _strategyCard(String name, String info, String status, String pnl) {
    final statusColor = {'running': const Color(0xFF00B894), 'paused': const Color(0xFFFECA57), 'stopped': const Color(0xFFFF6B6B)}[status] ?? Colors.grey;
    final statusText = {'running': '运行中', 'paused': '已暂停', 'stopped': '已停止'}[status] ?? status;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(status == 'running' ? Icons.play_arrow : status == 'paused' ? Icons.pause : Icons.stop, color: statusColor),
        ),
        title: Text(name),
        subtitle: Text(info),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
            Text(pnl, style: TextStyle(color: pnl.startsWith('+') ? const Color(0xFF00B894) : const Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _tradeItem(String symbol, String side, String price, String pnl, bool isProfit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(side == 'BUY' ? Icons.arrow_downward : Icons.arrow_upward, color: side == 'BUY' ? const Color(0xFF00B894) : const Color(0xFFFF6B6B)),
        title: Text('$symbol $side'),
        subtitle: Text('价格: \$$price'),
        trailing: Text(pnl, style: TextStyle(color: isProfit ? const Color(0xFF00B894) : const Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _EquityCurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D2D3)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF00D2D3).withOpacity(0.3), const Color(0xFF00D2D3).withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final points = [
      Offset(0, size.height * 0.6),
      Offset(size.width * 0.1, size.height * 0.55),
      Offset(size.width * 0.2, size.height * 0.5),
      Offset(size.width * 0.3, size.height * 0.52),
      Offset(size.width * 0.4, size.height * 0.4),
      Offset(size.width * 0.5, size.height * 0.35),
      Offset(size.width * 0.6, size.height * 0.38),
      Offset(size.width * 0.7, size.height * 0.3),
      Offset(size.width * 0.8, size.height * 0.25),
      Offset(size.width * 0.9, size.height * 0.2),
      Offset(size.width, size.height * 0.15),
    ];

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    // 填充
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fillPath, fillPaint);

    // 线条
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ==================== 策略页面 ====================

class StrategyPage extends StatelessWidget {
  const StrategyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('策略管理'),
        actions: [
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _showCreateDialog(context)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _strategyTile('均线交叉策略', 'BTCUSDT · 1h · MA(5/20)', 'running', true),
          _strategyTile('RSI 反转策略', 'ETHUSDT · 4h · RSI(14)', 'paused', false),
          _strategyTile('布林带回归', 'BTCUSDT · 15m · BB(20)', 'stopped', false),
          _strategyTile('MACD 趋势', 'BTCUSDT · 1h · MACD(12,26)', 'draft', true),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI 生成'),
        backgroundColor: const Color(0xFF00D2D3),
      ),
    );
  }

  Widget _strategyTile(String name, String info, String status, bool isAI) {
    final statusColor = {'running': const Color(0xFF00B894), 'paused': const Color(0xFFFECA57), 'stopped': const Color(0xFFFF6B6B), 'draft': Colors.grey}[status] ?? Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(status == 'running' ? Icons.play_arrow : Icons.code, color: statusColor),
        ),
        title: Row(
          children: [
            Text(name),
            if (isAI) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: const Color(0xFF00D2D3).withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: const Text('AI', style: TextStyle(fontSize: 10, color: Color(0xFF00D2D3))),
              ),
            ],
          ],
        ),
        subtitle: Text(info),
        trailing: IconButton(
          icon: Icon(status == 'running' ? Icons.pause_circle : Icons.play_circle, color: statusColor, size: 36),
          onPressed: () {},
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🎯 AI 策略生成', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('用自然语言描述你的交易想法', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            const TextField(
              maxLines: 4,
              decoration: InputDecoration(
                hintText: '例如: 当 RSI 低于 30 且成交量放大时买入...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('生成策略'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 交易页面 ====================

class TradingPage extends StatelessWidget {
  const TradingPage({super.key});

  @override
  Widget build(BuildContext context) {
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
        body: TabBarView(
          children: [
            // 持仓
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _positionCard('BTCUSDT', 'LONG', '62,450', '63,100', '+1.04%', true),
                _positionCard('ETHUSDT', 'SHORT', '3,150', '3,120', '+0.95%', true),
              ],
            ),
            // 历史
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _historyItem('BTCUSDT', 'BUY', '61,200', '+3.2%', true),
                _historyItem('ETHUSDT', 'SELL', '3,200', '-1.5%', false),
                _historyItem('BTCUSDT', 'BUY', '60,800', '+5.1%', true),
                _historyItem('SOLUSDT', 'BUY', '145.50', '+2.8%', true),
                _historyItem('BTCUSDT', 'SELL', '63,100', '-0.8%', false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _positionCard(String symbol, String side, String entry, String current, String pnl, bool isProfit) {
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
                    color: (side == 'LONG' ? const Color(0xFF00B894) : const Color(0xFFFF6B6B)).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(side, style: TextStyle(color: side == 'LONG' ? const Color(0xFF00B894) : const Color(0xFFFF6B6B), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Text(symbol, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(pnl, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isProfit ? const Color(0xFF00B894) : const Color(0xFFFF6B6B))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _detail('入场价', '\$$entry'),
                _detail('当前价', '\$$current'),
                _detail('数量', '0.1 BTC'),
                _detail('盈亏', pnl),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyItem(String symbol, String side, String price, String pnl, bool isProfit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(side == 'BUY' ? Icons.arrow_downward : Icons.arrow_upward, color: side == 'BUY' ? const Color(0xFF00B894) : const Color(0xFFFF6B6B)),
        title: Text('$symbol $side'),
        subtitle: Text('价格: \$$price'),
        trailing: Text(pnl, style: TextStyle(color: isProfit ? const Color(0xFF00B894) : const Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      ],
    );
  }
}

// ==================== AI 对话页面 ====================

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final _controller = TextEditingController();
  final _messages = <_ChatMessage>[
    _ChatMessage('assistant', '👋 你好！我是 QuantFlow AI 交易助手。\n\n我可以帮你：\n• 📊 分析市场走势\n• 🎯 生成交易策略\n• 🛡️ 评估持仓风险\n• 📎 分析 EA 源码\n\n有什么想问的？'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFF00D2D3)]), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 助手', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('智能分析 · 策略优化', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () {
            setState(() {
              _messages.clear();
              _messages.add(_ChatMessage('assistant', '对话已清空。有什么想问的？'));
            });
          }),
        ],
      ),
      body: Column(
        children: [
          // 快捷操作
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                _chip('📊 市场分析'),
                _chip('🎯 生成策略'),
                _chip('🛡️ 风险评估'),
                _chip('📎 分析 EA'),
              ],
            ),
          ),
          // 消息列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) => _messageBubble(_messages[i]),
            ),
          ),
          // 输入框
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(color: const Color(0xFF0F0F23), border: Border(top: BorderSide(color: Colors.grey[900]!))),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: _send,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFF00D2D3)]), shape: BoxShape.circle),
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () => _send(_controller.text)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(label, style: const TextStyle(fontSize: 13)),
        onPressed: () => _send(label),
        backgroundColor: const Color(0xFF1A1A2E),
        side: BorderSide(color: Colors.grey[800]!),
      ),
    );
  }

  Widget _messageBubble(_ChatMessage msg) {
    final isUser = msg.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF6C5CE7).withOpacity(0.2) : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4), bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(color: isUser ? const Color(0xFF6C5CE7).withOpacity(0.3) : Colors.grey[800]!),
        ),
        child: Text(msg.content, style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(_ChatMessage('user', text.trim()));
      _controller.clear();
    });
    // 模拟 AI 回复
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _messages.add(_ChatMessage('assistant', '收到你的消息: "$text"\n\n⚠️ 当前为离线模式，请配置 AI 引擎地址后即可使用完整功能。\n\n设置路径: 设置 → AI 引擎地址'));
      });
    });
  }
}

class _ChatMessage {
  final String role;
  final String content;
  _ChatMessage(this.role, this.content);
}

// ==================== 分析页面 ====================

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据分析')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 指标网格
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _metricTile('总收益', '+\$1,250', const Color(0xFF00B894)),
              _metricTile('总交易', '24 笔', const Color(0xFF00D2D3)),
              _metricTile('胜率', '58.3%', const Color(0xFF00B894)),
              _metricTile('夏普比率', '1.85', Colors.white),
            ],
          ),
          const SizedBox(height: 16),

          // 月度收益
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('月度收益', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 180,
                    child: CustomPaint(
                      size: const Size(double.infinity, 180),
                      painter: _BarChartPainter(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 交易分布
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('交易分布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _legendItem(const Color(0xFF00B894), '盈利 58%'),
                      const SizedBox(width: 32),
                      _legendItem(const Color(0xFFFF6B6B), '亏损 42%'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricTile(String label, String value, Color color) {
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

  Widget _legendItem(Color color, String label) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 13)),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final data = [3.2, -1.5, 5.8, 2.1, -0.8, 4.5, 7.2];
    final labels = ['1月', '2月', '3月', '4月', '5月', '6月', '7月'];
    final barWidth = size.width / data.length * 0.6;
    final gap = size.width / data.length;

    for (var i = 0; i < data.length; i++) {
      final val = data[i];
      final barHeight = (val.abs() / 10) * size.height * 0.8;
      final x = i * gap + (gap - barWidth) / 2;
      final y = val >= 0 ? size.height * 0.5 - barHeight : size.height * 0.5;

      final paint = Paint()
        ..color = val >= 0 ? const Color(0xFF00B894) : const Color(0xFFFF6B6B)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, barHeight), const Radius.circular(4)),
        paint,
      );

      // 标签
      final tp = TextPainter(
        text: TextSpan(text: labels[i], style: TextStyle(color: Colors.grey[500], fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(i * gap + (gap - tp.width) / 2, size.height - 16));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
