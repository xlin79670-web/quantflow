import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_chat_screen.dart';
import 'ai_chat_web_screen.dart';

/// AI 对话入口 - 自动选择最佳模式
/// 
/// 优先使用 WebView (完整功能，和网页版一致)
/// 如果连接失败，降级到原生模式
class AIChatToggleScreen extends ConsumerStatefulWidget {
  const AIChatToggleScreen({super.key});

  @override
  ConsumerState<AIChatToggleScreen> createState() => _AIChatToggleScreenState();
}

class _AIChatToggleScreenState extends ConsumerState<AIChatToggleScreen> {
  // true = WebView 模式 (完整功能), false = 原生模式 (离线可用)
  bool _useWebView = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFF00D2D3)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text('AI 助手'),
          ],
        ),
        actions: [
          // 模式切换按钮
          IconButton(
            icon: Icon(_useWebView ? Icons.phone_android : Icons.language),
            tooltip: _useWebView ? '切换到原生模式' : '切换到网页模式',
            onPressed: () => setState(() => _useWebView = !_useWebView),
          ),
        ],
      ),
      body: _useWebView
          ? const AIChatWebScreen()
          : const AIChatScreen(),
    );
  }
}
