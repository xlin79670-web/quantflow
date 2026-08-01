import 'package:flutter/material.dart';

class AppTheme {
  // 品牌色
  static const _primary = Color(0xFF6C5CE7);    // 紫色
  static const _accent = Color(0xFF00D2D3);     // 青色
  static const _profit = Color(0xFF00B894);     // 绿色 (盈利)
  static const _loss = Color(0xFFFF6B6B);       // 红色 (亏损)
  static const _warning = Color(0xFFFECA57);    // 黄色 (警告)

  // 暗色主题
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: _primary,
      secondary: _accent,
      surface: const Color(0xFF1A1A2E),
      onSurface: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFF0F0F23),
    cardColor: const Color(0xFF1A1A2E),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0F0F23),
      elevation: 0,
      centerTitle: true,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF1A1A2E),
      indicatorColor: _primary.withOpacity(0.3),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF16213E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    cardTheme: CardTheme(
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
  );

  // 亮色主题
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: _primary,
      secondary: _accent,
    ),
  );

  // 交易专用颜色
  static const profitColor = _profit;
  static const lossColor = _loss;
  static const warningColor = _warning;
  static const accentColor = _accent;
}
