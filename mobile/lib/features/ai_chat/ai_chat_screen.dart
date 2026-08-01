import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/services/api_service.dart';

class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[
    ChatMessage(
      role: 'assistant',
      content: '👋 你好！我是 QuantFlow AI 交易助手。\n\n'
          '我可以帮你：\n'
          '• 分析策略表现和盈亏原因\n'
          '• 解读市场走势和新闻事件\n'
          '• 生成和优化交易策略\n'
          '• 评估风险和提供建议\n\n'
          '有什么想问的？',
    ),
  ];
  bool _isLoading = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFF00D2D3)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome, size: 20, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI 交易助手', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('智能分析 · 策略优化', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'clear', child: Text('清空对话')),
              const PopupMenuItem(value: 'generate', child: Text('🎯 生成策略')),
              const PopupMenuItem(value: 'analyze', child: Text('📊 分析市场')),
              const PopupMenuItem(value: 'risk', child: Text('🛡️ 风险评估')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 快捷操作栏
          _QuickActions(onTap: _sendQuickAction),

          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (_, index) {
                if (index == _messages.length) {
                  return const _TypingIndicator();
                }
                return _MessageBubble(
                  message: _messages[index],
                  onCopy: (text) {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制'), duration: Duration(seconds: 1)),
                    );
                  },
                );
              },
            ),
          ),

          // 输入框
          _InputBar(
            controller: _controller,
            isLoading: _isLoading,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text.trim()));
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    // 调用 AI API
    _callAI(text.trim());
  }

  void _sendQuickAction(String action) {
    _sendMessage(action);
  }

  Future<void> _callAI(String message) async {
    try {
      final api = ref.read(apiServiceProvider);
      final result = await api.aiChat(message);

      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: result['response'] ?? '抱歉，我无法处理这个请求。',
        ));
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: '⚠️ 连接 AI 服务失败，请稍后重试。\n错误: $e',
        ));
        _isLoading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'clear':
        setState(() {
          _messages.clear();
          _messages.add(ChatMessage(role: 'assistant', content: '对话已清空。有什么想问的？'));
        });
        break;
      case 'generate':
        _showGenerateStrategyDialog();
        break;
      case 'analyze':
        _sendMessage('请分析 BTC 当前的市场走势，给出交易建议');
        break;
      case 'risk':
        _sendMessage('请评估我当前持仓的风险');
        break;
    }
  }

  void _showGenerateStrategyDialog() {
    final descController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎯 AI 生成策略'),
        content: TextField(
          controller: descController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: '用自然语言描述你的交易想法...\n例如: 当 RSI 低于 30 且成交量放大时买入',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendMessage('请根据以下描述生成交易策略:\n${descController.text}');
            },
            child: const Text('生成'),
          ),
        ],
      ),
    );
  }
}

// ==================== 数据模型 ====================

class ChatMessage {
  final String role; // user, assistant
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ==================== 快捷操作栏 ====================

class _QuickActions extends StatelessWidget {
  final Function(String) onTap;
  const _QuickActions({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final actions = [
      ('📊', '市场分析'),
      ('🎯', '生成策略'),
      ('🛡️', '风险评估'),
      ('📈', '策略优化'),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          return ActionChip(
            avatar: Text(actions[i].$1),
            label: Text(actions[i].$2, style: const TextStyle(fontSize: 13)),
            onPressed: () => onTap('请帮我${actions[i].$2}'),
            backgroundColor: const Color(0xFF1A1A2E),
            side: BorderSide(color: Colors.grey[800]!),
          );
        },
      ),
    );
  }
}

// ==================== 消息气泡 ====================

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final Function(String) onCopy;

  const _MessageBubble({required this.message, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: GestureDetector(
          onLongPress: () => onCopy(message.content),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isUser ? AppTheme.accentColor.withOpacity(0.2) : const Color(0xFF1A1A2E),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isUser ? 16 : 4),
                bottomRight: Radius.circular(isUser ? 4 : 16),
              ),
              border: Border.all(
                color: isUser ? AppTheme.accentColor.withOpacity(0.3) : Colors.grey[800]!,
              ),
            ),
            child: isUser
                ? Text(message.content, style: const TextStyle(fontSize: 15))
                : MarkdownBody(
                    data: message.content,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(fontSize: 15, color: Colors.white),
                      code: TextStyle(
                        backgroundColor: Colors.grey[900],
                        color: AppTheme.accentColor,
                        fontSize: 13,
                      ),
                      codeblockDecoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ==================== 输入框 ====================

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isLoading;
  final Function(String) onSend;

  const _InputBar({
    required this.controller,
    required this.isLoading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F23),
        border: Border(top: BorderSide(color: Colors.grey[900]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 4,
              minLines: 1,
              enabled: !isLoading,
              decoration: InputDecoration(
                hintText: '问我任何交易相关的问题...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              onSubmitted: onSend,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF6C5CE7), Color(0xFF00D2D3)]),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: isLoading ? null : () => onSend(controller.text),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 打字指示器 ====================

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: Colors.grey[800]!),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final delay = i * 0.3;
                final opacity = (((_controller.value + delay) % 1.0) * 2 - 1).abs();
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[500]!.withOpacity(0.3 + opacity * 0.7),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
