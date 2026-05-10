import 'package:flutter/material.dart';

class AppTheme {
  static const Color bgColor = Color(0xFFE5E5E5);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color surfaceHover = Color(0xFFF9FAFB);
  static const Color textMain = Color(0xFF000000);
  static const Color textMuted = Color(0xFF888888);
  static const Color borderColor = Color(0xFFEAEAEA);
  static const Color accentColor = Color(0xFF000000);
  static const Color accentLight = Color(0xFFF5F5F5);

  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: bgColor,
      primaryColor: accentColor,
      colorScheme: const ColorScheme.light(
        primary: accentColor,
        secondary: accentColor,
        surface: surfaceColor,
        onSurface: textMain,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderColor),
        ),
        margin: const EdgeInsets.only(bottom: 24),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textMain),
        titleTextStyle: TextStyle(
          color: textMain,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
    );
  }
}
