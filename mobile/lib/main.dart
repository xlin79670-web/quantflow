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
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C5CE7),
          secondary: Color(0xFF00D2D3),
          surface: Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F23),
        cardColor: const Color(0xFF1A1A2E),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF0F0F23), elevation: 0, centerTitle: true),
      ),
      home: const MainShell(),
    );
  }
}

// ==================== 主框架 ====================

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  final _pages = const [
    DashboardPage(), StrategyPage(), TradingPage(), AIChatPage(), AnalyticsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _pages[_index],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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

// ==================== 工具方法 ====================

void _snack(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}

void _toast(BuildContext ctx, String title, String msg) {
  showDialog(context: ctx, builder: (_) => AlertDialog(
    title: Text(title), content: Text(msg),
    actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定'))],
  ));
}

// ==================== 1. 仪表盘 ====================

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QuantFlow', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _toast(context, '通知', '暂无新通知')),
          IconButton(icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()))),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async { await Future.delayed(const Duration(seconds: 1)); _snack(context, '已刷新'); },
        child: ListView(padding: const EdgeInsets.all(16), children: [
          // 总览
          Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('总资产', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                const SizedBox(height: 4),
                const Text('\$10,000.00', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('今日收益', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                const SizedBox(height: 4),
                const Text('+2.5%', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF00B894))),
              ]),
            ]),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
              child: const Text('演示数据', style: TextStyle(fontSize: 10, color: Colors.orange)),
            )),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _stat('BTC', '\$62,450'), _stat('24h', '-1.2%'), _stat('胜率', '58%'), _stat('交易', '24'),
            ]),
          ]))),
          const SizedBox(height: 16),
          // 收益曲线
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('收益曲线', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('\$12,456', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ]),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _snack(context, '点击了收益曲线'),
              child: SizedBox(height: 180, child: CustomPaint(size: const Size(double.infinity, 180), painter: _CurvePainter())),
            ),
          ]))),
          const SizedBox(height: 16),
          // 策略状态
          const Text('策略状态', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _stratCard(context, '均线交叉策略', 'BTCUSDT · 1h', 'running', '+12.5%'),
          _stratCard(context, 'RSI 反转策略', 'ETHUSDT · 4h', 'paused', '+8.3%'),
          _stratCard(context, '布林带回归', 'BTCUSDT · 15m', 'stopped', '-2.1%'),
          const SizedBox(height: 16),
          const Text('最近交易', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _trade(context, 'BTCUSDT', 'BUY', '62,450', '+3.2%', true),
          _trade(context, 'ETHUSDT', 'SELL', '3,120', '-1.5%', false),
          _trade(context, 'BTCUSDT', 'BUY', '61,800', '+5.1%', true),
        ]),
      ),
    );
  }

  Widget _stat(String l, String v) => Column(children: [
    Text(l, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
    const SizedBox(height: 4),
    Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
  ]);

  Widget _stratCard(BuildContext ctx, String name, String info, String status, String pnl) {
    final c = {'running': const Color(0xFF00B894), 'paused': const Color(0xFFFECA57), 'stopped': const Color(0xFFFF6B6B)}[status] ?? Colors.grey;
    final t = {'running': '运行中', 'paused': '已暂停', 'stopped': '已停止'}[status] ?? status;
    return Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: CircleAvatar(backgroundColor: c.withOpacity(0.2), child: Icon(status == 'running' ? Icons.play_arrow : status == 'paused' ? Icons.pause : Icons.stop, color: c)),
      title: Text(name), subtitle: Text(info),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(t, style: TextStyle(color: c, fontSize: 12)),
        Text(pnl, style: TextStyle(color: pnl.startsWith('+') ? const Color(0xFF00B894) : const Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
      ]),
      onTap: () => _toast(ctx, name, '状态: $t\n盈亏: $pnl\n$info'),
    ));
  }

  Widget _trade(BuildContext ctx, String sym, String side, String price, String pnl, bool ok) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
    leading: Icon(side == 'BUY' ? Icons.arrow_downward : Icons.arrow_upward, color: ok ? const Color(0xFF00B894) : const Color(0xFFFF6B6B)),
    title: Text('$sym $side'), subtitle: Text('价格: \$$price'),
    trailing: Text(pnl, style: TextStyle(color: ok ? const Color(0xFF00B894) : const Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
    onTap: () => _snack(ctx, '$sym $side @ \$$price → $pnl'),
  ));
}

class _CurvePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF00D2D3)..strokeWidth = 2.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final fill = Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [const Color(0xFF00D2D3).withOpacity(0.3), const Color(0xFF00D2D3).withOpacity(0)]).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    final pts = [Offset(0, size.height*.6), Offset(size.width*.1, size.height*.55), Offset(size.width*.2, size.height*.5), Offset(size.width*.3, size.height*.52), Offset(size.width*.4, size.height*.4), Offset(size.width*.5, size.height*.35), Offset(size.width*.6, size.height*.38), Offset(size.width*.7, size.height*.3), Offset(size.width*.8, size.height*.25), Offset(size.width*.9, size.height*.2), Offset(size.width, size.height*.15)];
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var p in pts.skip(1)) path.lineTo(p.dx, p.dy);
    canvas.drawPath(Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close(), fill);
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ==================== 2. 策略管理 ====================

class StrategyPage extends StatelessWidget {
  const StrategyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strategies = [
      {'name': '均线交叉策略', 'info': 'BTCUSDT · 1h · MA(5/20)', 'status': 'running', 'ai': true},
      {'name': 'RSI 反转策略', 'info': 'ETHUSDT · 4h · RSI(14)', 'status': 'paused', 'ai': false},
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('策略管理'), actions: [
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => _showCreate(context)),
      ]),
      body: RefreshIndicator(
        onRefresh: () async { await Future.delayed(const Duration(seconds: 1)); _snack(context, '已刷新'); },
        child: strategies.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.code_off, size: 80, color: Colors.grey[700]),
              const SizedBox(height: 16),
              const Text('还没有策略', style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('创建你的第一个量化策略', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              ElevatedButton.icon(onPressed: () => _showCreate(context), icon: const Icon(Icons.auto_awesome), label: const Text('AI 生成策略')),
            ]))
          : ListView.builder(padding: const EdgeInsets.all(16), itemCount: strategies.length, itemBuilder: (_, i) {
              final s = strategies[i];
              final sc = {'running': const Color(0xFF00B894), 'paused': const Color(0xFFFECA57)}[s['status']] ?? Colors.grey;
              return Card(margin: const EdgeInsets.only(bottom: 12), child: ListTile(
                leading: CircleAvatar(backgroundColor: sc.withOpacity(0.2), child: Icon(s['status'] == 'running' ? Icons.play_arrow : Icons.pause, color: sc)),
                title: Row(children: [
                  Text(s['name'] as String),
                  if (s['ai'] == true) ...[const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xFF00D2D3).withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: const Text('AI', style: TextStyle(fontSize: 10, color: Color(0xFF00D2D3))))],
                ]),
                subtitle: Text(s['info'] as String),
                trailing: IconButton(icon: Icon(s['status'] == 'running' ? Icons.pause_circle : Icons.play_circle, color: sc, size: 36), onPressed: () => _snack(context, '${s['status'] == 'running' ? '暂停' : '启动'} ${s['name']}')),
                onTap: () => _toast(context, s['name'] as String, '${s['info']}\n状态: ${s['status']}'),
              ));
            }),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreate(context),
        icon: const Icon(Icons.auto_awesome), label: const Text('AI 生成'),
        backgroundColor: const Color(0xFF00D2D3),
      ),
    );
  }

  void _showCreate(BuildContext ctx) {
    final ctrl = TextEditingController();
    showModalBottomSheet(context: ctx, isScrollControlled: true, backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🎯 AI 策略生成', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('用自然语言描述你的交易想法', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          TextField(controller: ctrl, maxLines: 4, decoration: const InputDecoration(hintText: '例如: 当 RSI 低于 30 且成交量放大时买入...', border: OutlineInputBorder())),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: () { Navigator.pop(ctx); _snack(ctx, '策略生成中... "${ctrl.text}"'); },
            icon: const Icon(Icons.auto_awesome), label: const Text('生成策略'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6C5CE7)),
          )),
        ]),
      ),
    );
  }
}

// ==================== 3. 交易 ====================

class TradingPage extends StatelessWidget {
  const TradingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(length: 2, child: Scaffold(
      appBar: AppBar(title: const Text('交易'), bottom: const TabBar(tabs: [
        Tab(text: '持仓', icon: Icon(Icons.account_balance_wallet_outlined)),
        Tab(text: '历史', icon: Icon(Icons.history)),
      ])),
      body: TabBarView(children: [
        RefreshIndicator(onRefresh: () async => _snack(context, '已刷新持仓'), child: ListView(padding: const EdgeInsets.all(16), children: [
          _pos(context, 'BTCUSDT', 'LONG', '62,450', '63,100', '+1.04%', true),
          _pos(context, 'ETHUSDT', 'SHORT', '3,150', '3,120', '+0.95%', true),
        ])),
        RefreshIndicator(onRefresh: () async => _snack(context, '已刷新历史'), child: ListView(padding: const EdgeInsets.all(16), children: [
          _hist(context, 'BTCUSDT', 'BUY', '61,200', '+3.2%', true),
          _hist(context, 'ETHUSDT', 'SELL', '3,200', '-1.5%', false),
          _hist(context, 'BTCUSDT', 'BUY', '60,800', '+5.1%', true),
          _hist(context, 'SOLUSDT', 'BUY', '145.50', '+2.8%', true),
        ])),
      ]),
    ));
  }

  Widget _pos(BuildContext ctx, String sym, String side, String entry, String cur, String pnl, bool ok) => Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
    Row(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: (side == 'LONG' ? const Color(0xFF00B894) : const Color(0xFFFF6B6B)).withOpacity(0.15), borderRadius: BorderRadius.circular(6)), child: Text(side, style: TextStyle(color: side == 'LONG' ? const Color(0xFF00B894) : const Color(0xFFFF6B6B), fontWeight: FontWeight.bold, fontSize: 12))),
      const SizedBox(width: 12), Text(sym, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const Spacer(), Text(pnl, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ok ? const Color(0xFF00B894) : const Color(0xFFFF6B6B))),
    ]),
    const SizedBox(height: 12),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      _det('入场价', '\$$entry'), _det('当前价', '\$$cur'), _det('数量', '0.1'), _det('盈亏', pnl),
    ]),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => _snack(ctx, '修改 $sym 止损'), child: const Text('修改止损'))),
      const SizedBox(width: 8),
      Expanded(child: ElevatedButton(onPressed: () => _snack(ctx, '平仓 $sym'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B)), child: const Text('平仓'))),
    ]),
  ])));

  Widget _hist(BuildContext ctx, String sym, String side, String price, String pnl, bool ok) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
    leading: Icon(side == 'BUY' ? Icons.arrow_downward : Icons.arrow_upward, color: side == 'BUY' ? const Color(0xFF00B894) : const Color(0xFFFF6B6B)),
    title: Text('$sym $side'), subtitle: Text('价格: \$$price'),
    trailing: Text(pnl, style: TextStyle(color: ok ? const Color(0xFF00B894) : const Color(0xFFFF6B6B), fontWeight: FontWeight.bold)),
    onTap: () => _snack(ctx, '$sym $side @ \$$price → $pnl'),
  ));

  Widget _det(String l, String v) => Column(children: [Text(l, style: TextStyle(fontSize: 11, color: Colors.grey[500])), const SizedBox(height: 2), Text(v, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))]);
}

// ==================== 4. AI 对话 ====================

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});
  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final _ctrl = TextEditingController();
  final _msgs = <_Msg>[
    _Msg('assistant', '👋 你好！我是 QuantFlow AI 交易助手。\n\n我可以帮你：\n• 📊 分析市场走势\n• 🎯 生成交易策略\n• 🛡️ 评估持仓风险\n• 📎 分析 EA 源码\n\n有什么想问的？'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFF00D2D3)]), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.auto_awesome, size: 18, color: Colors.white)),
        const SizedBox(width: 10),
        const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('AI 助手', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), Text('智能分析 · 策略优化', style: TextStyle(fontSize: 11, color: Colors.grey))]),
      ]), actions: [
        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () { setState(() { _msgs.clear(); _msgs.add(_Msg('assistant', '对话已清空。有什么想问的？')); }); _snack(context, '已清空对话'); }),
      ]),
      body: Column(children: [
        SizedBox(height: 48, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), children: [
          _chip('📊 市场分析'), _chip('🎯 生成策略'), _chip('🛡️ 风险评估'), _chip('📎 分析 EA'),
        ])),
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: _msgs.length, itemBuilder: (_, i) {
          final m = _msgs[i]; final isUser = m.role == 'user';
          return Align(alignment: isUser ? Alignment.centerRight : Alignment.centerLeft, child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? const Color(0xFF6C5CE7).withOpacity(0.2) : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: Radius.circular(isUser ? 16 : 4), bottomRight: Radius.circular(isUser ? 4 : 16)),
              border: Border.all(color: isUser ? const Color(0xFF6C5CE7).withOpacity(0.3) : Colors.grey[800]!),
            ),
            child: Text(m.content, style: const TextStyle(fontSize: 15)),
          ));
        })),
        Container(padding: const EdgeInsets.fromLTRB(16, 8, 16, 16), decoration: BoxDecoration(color: const Color(0xFF0F0F23), border: Border(top: BorderSide(color: Colors.grey[900]!))), child: Row(children: [
          Expanded(child: TextField(controller: _ctrl, decoration: InputDecoration(hintText: '输入消息...', hintStyle: TextStyle(color: Colors.grey[600]), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none), filled: true, fillColor: const Color(0xFF1A1A2E), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)), onSubmitted: _send)),
          const SizedBox(width: 8),
          Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFF00D2D3)]), shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: () => _send(_ctrl.text))),
        ])),
      ]),
    );
  }

  Widget _chip(String l) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text(l, style: const TextStyle(fontSize: 13)), onPressed: () => _send(l), backgroundColor: const Color(0xFF1A1A2E), side: BorderSide(color: Colors.grey[800]!)));

  void _send(String text) {
    if (text.trim().isEmpty) return;
    setState(() { _msgs.add(_Msg('user', text.trim())); _ctrl.clear(); });
    Future.delayed(const Duration(seconds: 1), () {
      setState(() { _msgs.add(_Msg('assistant', '收到: "$text"\n\n⚠️ 当前为离线模式，请在设置中配置 AI 引擎地址。\n\n路径: 设置 → AI 设置 → AI 引擎地址')); });
    });
  }
}

class _Msg { final String role; final String content; _Msg(this.role, this.content); }

// ==================== 5. 数据分析 ====================

class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('数据分析')),
      body: RefreshIndicator(
        onRefresh: () async => _snack(context, '已刷新'),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, children: [
            _metric('总收益', '+\$1,250', const Color(0xFF00B894)),
            _metric('总交易', '24 笔', const Color(0xFF00D2D3)),
            _metric('胜率', '58.3%', const Color(0xFF00B894)),
            _metric('夏普比率', '1.85', Colors.white),
          ]),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(4)), child: const Text('演示数据', style: TextStyle(fontSize: 10, color: Colors.orange)))),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('月度收益', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(height: 180, child: CustomPaint(size: const Size(double.infinity, 180), painter: _BarPainter())),
          ]))),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('交易分布', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _legend(const Color(0xFF00B894), '盈利 58%'), const SizedBox(width: 32), _legend(const Color(0xFFFF6B6B), '亏损 42%'),
            ]),
          ]))),
          const SizedBox(height: 16),
          Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('策略对比', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _stratRow('均线交叉', '+12.5%', '1.85', true),
            _stratRow('RSI 反转', '+8.3%', '1.42', true),
            _stratRow('布林带', '-2.1%', '0.65', false),
          ]))),
        ]),
      ),
    );
  }

  Widget _metric(String l, String v, Color c) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(l, style: TextStyle(fontSize: 12, color: Colors.grey[500])), const SizedBox(height: 4), Text(v, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: c))])));
  Widget _legend(Color c, String l) => Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 6), Text(l, style: TextStyle(color: Colors.grey[400], fontSize: 13))]);
  Widget _stratRow(String name, String pnl, String sharpe, bool ok) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(name)), Text(pnl, style: TextStyle(color: ok ? const Color(0xFF00B894) : const Color(0xFFFF6B6B), fontWeight: FontWeight.bold)), const SizedBox(width: 16), Text('夏普 $sharpe', style: TextStyle(color: Colors.grey[400], fontSize: 12))]));
}

class _BarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final data = [3.2, -1.5, 5.8, 2.1, -0.8, 4.5, 7.2];
    final labels = ['1月', '2月', '3月', '4月', '5月', '6月', '7月'];
    final bw = size.width / data.length * 0.6;
    final gap = size.width / data.length;
    for (var i = 0; i < data.length; i++) {
      final v = data[i];
      final bh = (v.abs() / 10) * size.height * 0.8;
      final x = i * gap + (gap - bw) / 2;
      final y = v >= 0 ? size.height * 0.5 - bh : size.height * 0.5;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, bw, bh), const Radius.circular(4)), Paint()..color = v >= 0 ? const Color(0xFF00B894) : const Color(0xFFFF6B6B));
      // 标签
      final tp = TextPainter(text: TextSpan(text: labels[i], style: TextStyle(color: Colors.grey[500], fontSize: 10)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(i * gap + (gap - tp.width) / 2, size.height - 16));
      // 数值
      final vp = TextPainter(text: TextSpan(text: '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}%', style: TextStyle(color: v >= 0 ? const Color(0xFF00B894) : const Color(0xFFFF6B6B), fontSize: 9, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr)..layout();
      vp.paint(canvas, Offset(i * gap + (gap - vp.width) / 2, y - 14));
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ==================== 6. 设置页 ⭐ ====================

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _aiAnalysis = true;
  bool _aiEvolve = false;
  bool _aiRisk = true;
  bool _notifyTrade = true;
  bool _notifyRisk = true;
  bool _notifyDaily = false;
  bool _biometric = false;
  bool _darkMode = true;
  String _selectedModel = 'DeepSeek';
  String _selectedExchange = 'Binance';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(children: [
        // 账户区域
        Container(padding: const EdgeInsets.all(20), color: const Color(0xFF1A1A2E), child: Row(children: [
          CircleAvatar(radius: 28, backgroundColor: const Color(0xFF6C5CE7), child: const Text('Q', style: TextStyle(fontSize: 24, color: Colors.white))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('用户', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('user@quantflow.app', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ])),
          IconButton(icon: const Icon(Icons.edit), onPressed: () => _snack(context, '编辑个人资料')),
        ])),
        const SizedBox(height: 8),

        // 交易所配置
        _section('交易所配置', [
          ListTile(leading: const Icon(Icons.account_balance), title: const Text('当前交易所'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(_selectedExchange, style: const TextStyle(color: Color(0xFF00D2D3))), const Icon(Icons.chevron_right)]), onTap: () => _showExchangePicker(context)),
          ListTile(leading: const Icon(Icons.vpn_key), title: const Text('API Key 管理'), subtitle: const Text('管理交易所 API 密钥'), trailing: const Icon(Icons.chevron_right), onTap: () => _toast(context, 'API Key', '交易所: $_selectedExchange\n\n此处管理 API Key 和 Secret Key')),
          ListTile(leading: const Icon(Icons.swap_horiz), title: const Text('测试网/主网'), trailing: Switch(value: false, onChanged: (v) => _snack(context, v ? '已切换到测试网' : '已切换到主网'))),
        ]),

        // AI 设置
        _section('AI 设置', [
          ListTile(leading: const Icon(Icons.smart_toy), title: const Text('AI 模型'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(_selectedModel, style: const TextStyle(color: Color(0xFF00D2D3))), const Icon(Icons.chevron_right)]), onTap: () => _showModelPicker(context)),
          ListTile(leading: const Icon(Icons.link), title: const Text('AI 引擎地址'), subtitle: const Text('http://localhost:8000'), trailing: const Icon(Icons.chevron_right), onTap: () => _showUrlEditor(context)),
          SwitchListTile(secondary: const Icon(Icons.analytics), title: const Text('AI 市场分析'), subtitle: const Text('自动分析新闻和市场情绪'), value: _aiAnalysis, onChanged: (v) => setState(() => _aiAnalysis = v)),
          SwitchListTile(secondary: const Icon(Icons.psychology), title: const Text('策略自进化'), subtitle: const Text('AI 自动优化策略参数'), value: _aiEvolve, onChanged: (v) => setState(() => _aiEvolve = v)),
          SwitchListTile(secondary: const Icon(Icons.shield), title: const Text('AI 风险预警'), subtitle: const Text('高风险时自动暂停策略'), value: _aiRisk, onChanged: (v) => setState(() => _aiRisk = v)),
        ]),

        // 交易偏好
        _section('交易偏好', [
          ListTile(leading: const Icon(Icons.trending_down), title: const Text('最大回撤阈值'), subtitle: const Text('超过此值自动暂停'), trailing: const Text('15%', style: TextStyle(color: Color(0xFFFF6B6B))), onTap: () => _showSlider(context, '最大回撤', 5, 50, 15)),
          ListTile(leading: const Icon(Icons.pie_chart), title: const Text('单笔最大仓位'), subtitle: const Text('单笔交易最大占比'), trailing: const Text('20%', style: TextStyle(color: Color(0xFF00D2D3))), onTap: () => _showSlider(context, '单笔仓位', 5, 100, 20)),
          ListTile(leading: const Icon(Icons.speed), title: const Text('默认杠杆'), trailing: const Text('10x'), onTap: () => _snack(context, '设置默认杠杆')),
        ]),

        // 通知
        _section('通知', [
          SwitchListTile(secondary: const Icon(Icons.notifications), title: const Text('交易通知'), subtitle: const Text('开仓/平仓/止损触发'), value: _notifyTrade, onChanged: (v) => setState(() => _notifyTrade = v)),
          SwitchListTile(secondary: const Icon(Icons.warning), title: const Text('风险告警'), subtitle: const Text('异常波动和风险预警'), value: _notifyRisk, onChanged: (v) => setState(() => _notifyRisk = v)),
          SwitchListTile(secondary: const Icon(Icons.summarize), title: const Text('每日报告'), subtitle: const Text('每日收益汇总'), value: _notifyDaily, onChanged: (v) => setState(() => _notifyDaily = v)),
        ]),

        // 外观
        _section('外观', [
          SwitchListTile(secondary: const Icon(Icons.dark_mode), title: const Text('深色模式'), value: _darkMode, onChanged: (v) { setState(() => _darkMode = v); _snack(context, v ? '已切换到深色模式' : '已切换到浅色模式'); }),
          ListTile(leading: const Icon(Icons.language), title: const Text('语言'), trailing: Row(mainAxisSize: MainAxisSize.min, children: const [Text('中文'), Icon(Icons.chevron_right)]), onTap: () => _snack(context, '语言设置')),
        ]),

        // 安全
        _section('安全', [
          SwitchListTile(secondary: const Icon(Icons.fingerprint), title: const Text('生物识别'), subtitle: const Text('指纹/Face ID 登录'), value: _biometric, onChanged: (v) { setState(() => _biometric = v); _snack(context, v ? '已开启生物识别' : '已关闭生物识别'); }),
          ListTile(leading: const Icon(Icons.lock), title: const Text('修改密码'), trailing: const Icon(Icons.chevron_right), onTap: () => _snack(context, '修改密码')),
        ]),

        // 关于
        _section('关于', [
          ListTile(leading: const Icon(Icons.info_outline), title: const Text('版本'), trailing: const Text('v1.1.0', style: TextStyle(color: Colors.grey))),
          ListTile(leading: const Icon(Icons.description), title: const Text('用户协议'), trailing: const Icon(Icons.chevron_right), onTap: () => _snack(context, '用户协议')),
          ListTile(leading: const Icon(Icons.privacy_tip), title: const Text('隐私政策'), trailing: const Icon(Icons.chevron_right), onTap: () => _snack(context, '隐私政策')),
        ]),

        // 退出
        Padding(padding: const EdgeInsets.all(16), child: OutlinedButton.icon(
          onPressed: () => showDialog(context: context, builder: (_) => AlertDialog(
            title: const Text('确认退出'), content: const Text('确定要退出登录吗？'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
              TextButton(onPressed: () { Navigator.pop(context); _snack(context, '已退出登录'); }, child: const Text('退出', style: TextStyle(color: Colors.red))),
            ],
          )),
          icon: const Icon(Icons.logout, color: Colors.red), label: const Text('退出登录', style: TextStyle(color: Colors.red)),
          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size(double.infinity, 48)),
        )),
        const SizedBox(height: 32),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[500]))),
    ...children,
    const Divider(height: 1),
  ]);

  void _showExchangePicker(BuildContext ctx) {
    showDialog(context: ctx, builder: (_) => SimpleDialog(
      title: const Text('选择交易所'),
      children: ['Binance', 'OKX', 'Gate.io', 'Bybit'].map((e) => SimpleDialogOption(
        child: Row(children: [if (e == _selectedExchange) const Icon(Icons.check, color: Color(0xFF00D2D3)), const SizedBox(width: 8), Text(e)]),
        onPressed: () { setState(() => _selectedExchange = e); Navigator.pop(ctx); _snack(ctx, '已切换到 $e'); },
      )).toList(),
    ));
  }

  void _showModelPicker(BuildContext ctx) {
    showDialog(context: ctx, builder: (_) => SimpleDialog(
      title: const Text('选择 AI 模型'),
      children: ['DeepSeek', 'Qwen (通义)', 'GPT-4', '本地 Llama'].map((m) => SimpleDialogOption(
        child: Row(children: [if (m == _selectedModel) const Icon(Icons.check, color: Color(0xFF00D2D3)), const SizedBox(width: 8), Text(m)]),
        onPressed: () { setState(() => _selectedModel = m); Navigator.pop(ctx); _snack(ctx, '已切换到 $m'); },
      )).toList(),
    ));
  }

  void _showUrlEditor(BuildContext ctx) {
    final ctrl = TextEditingController(text: 'http://localhost:8000');
    showDialog(context: ctx, builder: (_) => AlertDialog(
      title: const Text('AI 引擎地址'),
      content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'http://your-server:8000', border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); _snack(ctx, '已保存: ${ctrl.text}'); }, child: const Text('保存')),
      ],
    ));
  }

  void _showSlider(BuildContext ctx, String title, double min, double max, double current) {
    showDialog(context: ctx, builder: (_) => AlertDialog(
      title: Text(title),
      content: StatefulBuilder(builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${current.toInt()}%', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Slider(value: current, min: min, max: max, divisions: (max - min).toInt(), onChanged: (v) => setS(() => current = v)),
      ])),
      actions: [ElevatedButton(onPressed: () { Navigator.pop(ctx); _snack(ctx, '$title 已设置为 ${current.toInt()}%'); }, child: const Text('确定'))],
    ));
  }
}
