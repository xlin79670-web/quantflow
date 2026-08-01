import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../shared/services/auth_service.dart';

class AIChatWebScreen extends ConsumerStatefulWidget {
  const AIChatWebScreen({super.key});

  @override
  ConsumerState<AIChatWebScreen> createState() => _AIChatWebScreenState();
}

class _AIChatWebScreenState extends ConsumerState<AIChatWebScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  // AI 引擎地址 (从配置或 API 获取)
  static const String _aiEngineUrl = 'http://localhost:8000';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _isLoading = true),
        onPageFinished: (_) => setState(() => _isLoading = false),
        onWebResourceError: (error) {
          setState(() {
            _error = '连接失败: ${error.description}\n\n请确认 AI 引擎已启动:\n$_aiEngineUrl';
            _isLoading = false;
          });
        },
      ))
      ..setBackgroundColor(const Color(0xFF0a0a1a))
      ..loadRequest(Uri.parse(_aiEngineUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // WebView
          if (_error == null)
            WebViewWidget(controller: _controller),

          // 错误页面
          if (_error != null)
            _ErrorView(
              error: _error!,
              onRetry: () {
                setState(() => _error = null);
                _controller.loadRequest(Uri.parse(_aiEngineUrl));
              },
            ),

          // 加载指示器
          if (_isLoading && _error == null)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                  SizedBox(height: 16),
                  Text('连接 AI 引擎...', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== 全屏对话模式 (嵌入式) ====================

class AIChatEmbeddedScreen extends ConsumerStatefulWidget {
  const AIChatEmbeddedScreen({super.key});

  @override
  ConsumerState<AIChatEmbeddedScreen> createState() => _AIChatEmbeddedScreenState();
}

class _AIChatEmbeddedScreenState extends ConsumerState<AIChatEmbeddedScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _isLoading = false),
      ))
      ..setBackgroundColor(const Color(0xFF0a0a1a))
      ..loadRequest(Uri.parse('http://localhost:8000'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, size: 20),
            SizedBox(width: 8),
            Text('AI 助手'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () {
              // 用系统浏览器打开
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

// ==================== 错误页面 ====================

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              '无法连接 AI 引擎',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _showSettings(context),
              icon: const Icon(Icons.settings),
              label: const Text('修改地址'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController(text: 'http://localhost:8000');
        return AlertDialog(
          title: const Text('AI 引擎地址'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'http://your-server:8000',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // TODO: 保存地址并重连
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }
}
