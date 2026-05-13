import 'package:flutter/material.dart';

class UserColorGenerator {
  static const List<Color> _palette = [
    Color(0xFFEB4D3D),
    Color(0xFF2D8CFF),
    Color(0xFF5BAE6E),
    Color(0xFFE8A931),
    Color(0xFF9B59B6),
    Color(0xFF1ABC9C),
    Color(0xFFE67E22),
    Color(0xFF34495E),
    Color(0xFF16A085),
    Color(0xFFC0392B),
  ];

  static Color forName(String name) {
    int hash = 0;
    for (final code in name.codeUnits) {
      hash = ((hash << 5) - hash) + code;
      hash = hash & 0xFFFFFFFF;
    }
    return _palette[hash.abs() % _palette.length];
  }
}