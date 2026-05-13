import 'package:flutter/material.dart';

class AppTheme {
  static Color accentColor = const Color(0xFF007AFF);
  static Color myBubbleColor = const Color(0xFFE7F3FF);

  static const List<Color> presetColors = [
    Color(0xFF007AFF), Color(0xFF34C759), Color(0xFFFF9500),
    Color(0xFFFF3B30), Color(0xFF5856D6), Color(0xFFFF2D55),
    Color(0xFF5AC8FA), Color(0xFFBF5AF2), Color(0xFFFFCC00),
    Color(0xFF8E8E93),
  ];

  static const Color bgColor = Color(0xFFF2F2F7);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color surfaceHover = Color(0xFFF9FAFB);
  static const Color textMain = Color(0xFF000000);
  static const Color textMuted = Color(0xFF8E8E93);
  static const Color borderColor = Color(0xFFE5E5EA);
  static const Color accentRed = Color(0xFFFF3B30);
  static const Color accentLight = Color(0xFFF5F5F5);
  static const Color placeholderBg = Color(0xFF1E293B);

  static void setColors({Color? accent, Color? bubble}) {
    if (accent != null) accentColor = accent;
    if (bubble != null) myBubbleColor = bubble;
  }

  static ThemeData get theme {
    return ThemeData(
      scaffoldBackgroundColor: bgColor,
      primaryColor: accentColor,
      colorScheme: ColorScheme.light(
        primary: accentColor,
        secondary: accentColor,
        surface: surfaceColor,
        onSurface: textMain,
        error: accentRed,
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.only(bottom: 24),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        iconTheme: IconThemeData(color: accentColor),
        titleTextStyle: const TextStyle(
          color: textMain, fontSize: 22, fontWeight: FontWeight.w600,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}