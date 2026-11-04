import 'package:flutter/material.dart';

/// Palette แบบ semantic — เพิ่มสีใหม่ต้องเพิ่ม field ที่นี่ ห้าม hardcode Color() ที่ call site
class AppPalette {
  const AppPalette({
    required this.scaffoldBg,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.textStrong,
    required this.textBody,
    required this.textMuted,
    required this.accent,
    required this.accentSurface,
    required this.onAccent,
    required this.highlight,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color scaffoldBg;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color textStrong;
  final Color textBody;
  final Color textMuted;
  final Color accent;
  final Color accentSurface;
  final Color onAccent;
  final Color highlight;
  final Color success;
  final Color warning;
  final Color danger;
}

const paletteLightMinimal = AppPalette(
  scaffoldBg: Color(0xFFF7F7F8),
  surface: Color(0xFFFFFFFF),
  surfaceMuted: Color(0xFFF1F2F4),
  border: Color(0xFFE3E5E9),
  textStrong: Color(0xFF16181D),
  textBody: Color(0xFF3C4149),
  textMuted: Color(0xFF8A909B),
  accent: Color(0xFF2D6CDF),
  accentSurface: Color(0xFFEAF1FE),
  onAccent: Color(0xFFFFFFFF),
  highlight: Color(0xFFFFE8A3),
  success: Color(0xFF2E9E6B),
  warning: Color(0xFFC98A14),
  danger: Color(0xFFD2503F),
);

AppPalette activePalette = paletteLightMinimal;

/// อ่านสีผ่าน getter → สลับ theme ได้โดยไม่แก้ call site
class AppColors {
  static Color get scaffoldBg => activePalette.scaffoldBg;
  static Color get surface => activePalette.surface;
  static Color get surfaceMuted => activePalette.surfaceMuted;
  static Color get border => activePalette.border;
  static Color get textStrong => activePalette.textStrong;
  static Color get textBody => activePalette.textBody;
  static Color get textMuted => activePalette.textMuted;
  static Color get accent => activePalette.accent;
  static Color get accentSurface => activePalette.accentSurface;
  static Color get onAccent => activePalette.onAccent;
  static Color get highlight => activePalette.highlight;
  static Color get success => activePalette.success;
  static Color get warning => activePalette.warning;
  static Color get danger => activePalette.danger;
}
