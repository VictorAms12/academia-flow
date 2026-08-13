import 'package:flutter/material.dart';

class AppColors {
  static const petroleum = Color(0xFF0F4C5C);
  static const petroleumDark = Color(0xFF091E26);
  static const petroleumCard = Color(0xFF103641);
  static const gold = Color(0xFFD4AF37);
  static const goldSoft = Color(0xFFC5A059);
  static const offWhite = Color(0xFFF8F9FA);
  static const ink = Color(0xFF1A1A1A);
  static const danger = Color(0xFFEA5C5C);
  static const success = Color(0xFF35B982);
  static const warning = Color(0xFFE3A53A);
}

class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.petroleum,
      brightness: Brightness.light,
      primary: AppColors.petroleum,
      secondary: AppColors.gold,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.offWhite,
      fontFamily: 'sans-serif',
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.petroleum.withValues(alpha: .12),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F4F5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.petroleum,
      brightness: Brightness.dark,
      primary: const Color(0xFF63B6C8),
      secondary: const Color(0xFFE1C359),
      surface: AppColors.petroleumCard,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.petroleumDark,
      fontFamily: 'sans-serif',
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: AppColors.petroleumCard.withValues(alpha: .88),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: const Color(0xFF0B2832),
        indicatorColor: AppColors.gold.withValues(alpha: .16),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0C2B35),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
