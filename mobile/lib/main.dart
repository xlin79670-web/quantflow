import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/strategy/strategy_list_screen.dart';
import 'features/strategy/strategy_detail_screen.dart';
import 'features/strategy/strategy_create_screen.dart';
import 'features/ai_chat/ai_chat_screen.dart';
import 'features/ai_chat/ai_chat_web_screen.dart';
import 'features/ai_chat/ai_chat_toggle_screen.dart';
import 'features/trading/trading_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/settings/settings_screen.dart';
import 'shared/services/auth_service.dart';

void main() {
  runApp(const ProviderScope(child: QuantFlowApp()));
}

class QuantFlowApp extends ConsumerWidget {
  const QuantFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'QuantFlow',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark, // 量化交易适合暗色主题
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==================== 路由配置 ====================

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      // 认证
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // 主界面 (底部导航)
      ShellRoute(
        builder: (_, __, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/strategy', builder: (_, __) => const StrategyListScreen()),
          GoRoute(path: '/trading', builder: (_, __) => const TradingScreen()),
          GoRoute(path: '/ai', builder: (_, __) => const AIChatToggleScreen()),
          GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
        ],
      ),

      // 二级页面
      GoRoute(path: '/strategy/create', builder: (_, __) => const StrategyCreateScreen()),
      GoRoute(path: '/strategy/:id', builder: (_, state) => StrategyDetailScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ],
  );
});

// ==================== 主界面 Shell ====================

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex(context),
        onDestinationSelected: (i) => _onTap(context, i),
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

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/strategy')) return 1;
    if (location.startsWith('/trading')) return 2;
    if (location.startsWith('/ai')) return 3;
    if (location.startsWith('/analytics')) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    const paths = ['/dashboard', '/strategy', '/trading', '/ai', '/analytics'];
    context.go(paths[index]);
  }
}
