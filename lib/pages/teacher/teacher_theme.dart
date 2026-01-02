import 'package:flutter/material.dart';

class AdminColors {
  static const Color bg = Color(0xFFF3F6FF);
  static const Color navy = Color(0xFF0F172A);
  static const Color uniBlue = Color(0xFF1D4ED8);
  static const Color border = Color(0xFFE2E8F0);

  static const Color green = Color(0xFF0EA984);
  static const Color red = Color(0xFFEF4444);
  static const Color purple = Color(0xFF6366F1);
  static const Color orange = Color(0xFFF59E0B);

  static const Color muted = Color(0xFF6B7280);
  static const Color smoke = Color(0xFFF8FAFF);

  static const LinearGradient heroGradient = LinearGradient(
    colors: [
      Color(0xFF0F172A),
      Color(0xFF1E3A8A),
      Color(0xFF0EA5E9),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardTint = LinearGradient(
    colors: [
      Colors.white,
      Color(0xFFF8FAFF),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const BoxShadow softShadow =
      BoxShadow(color: Color(0x190F172A), blurRadius: 24, offset: Offset(0, 12));
}
