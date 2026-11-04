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
    required this.kindPdf,
    required this.kindExcel,
    required this.kindWord,
    required this.kindText,
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

  /// สีประจำชนิดไฟล์ — ใช้แยกประเภทด้วยสายตาโดยไม่ต้องอ่านป้าย
  final Color kindPdf;
  final Color kindExcel;
  final Color kindWord;
  final Color kindText;
}

/// ★ ธีมหลัก — น้ำเงิน-indigo โทนเอกสาร/สายงาน
const paletteIndigo = AppPalette(
  scaffoldBg: Color(0xFFF6F7FB),
  surface: Color(0xFFFFFFFF),
  surfaceMuted: Color(0xFFF0F2F8),
  border: Color(0xFFE1E4EF),
  textStrong: Color(0xFF15182B),
  textBody: Color(0xFF3B4056),
  textMuted: Color(0xFF858CA5),
  accent: Color(0xFF4457D6),
  accentSurface: Color(0xFFECEFFE),
  onAccent: Color(0xFFFFFFFF),
  highlight: Color(0xFFFFE8A3),
  success: Color(0xFF2E9E6B),
  warning: Color(0xFFC98A14),
  danger: Color(0xFFD2503F),
  kindPdf: Color(0xFFC63B32),
  kindExcel: Color(0xFF1B7A4B),
  kindWord: Color(0xFF2B5FB8),
  kindText: Color(0xFF6B7280),
);

/// ม่วง-ลาเวนเดอร์ (โทนอ่อนนุ่ม)
const paletteViolet = AppPalette(
  scaffoldBg: Color(0xFFF8F5FD),
  surface: Color(0xFFFFFFFF),
  surfaceMuted: Color(0xFFF3EEFB),
  border: Color(0xFFE6DDF6),
  textStrong: Color(0xFF1E1430),
  textBody: Color(0xFF443658),
  textMuted: Color(0xFF8C7FA6),
  accent: Color(0xFF7A3FD0),
  accentSurface: Color(0xFFF1E9FD),
  onAccent: Color(0xFFFFFFFF),
  highlight: Color(0xFFFFE1A8),
  success: Color(0xFF2F9E70),
  warning: Color(0xFFC2851B),
  danger: Color(0xFFCF4A54),
  kindPdf: Color(0xFFC33B4D),
  kindExcel: Color(0xFF2A7A58),
  kindWord: Color(0xFF5B52C8),
  kindText: Color(0xFF7A7490),
);

/// เขียวมรกต-teal (สะอาดตา เหมาะอ่านนาน)
const paletteTeal = AppPalette(
  scaffoldBg: Color(0xFFF3F8F7),
  surface: Color(0xFFFFFFFF),
  surfaceMuted: Color(0xFFEAF2F0),
  border: Color(0xFFD8E6E2),
  textStrong: Color(0xFF11221F),
  textBody: Color(0xFF32453F),
  textMuted: Color(0xFF7E938D),
  accent: Color(0xFF0F6F62),
  accentSurface: Color(0xFFE1F1EC),
  onAccent: Color(0xFFFFFFFF),
  highlight: Color(0xFFFFE6A1),
  success: Color(0xFF2B8F62),
  warning: Color(0xFFBF8217),
  danger: Color(0xFFC94B3C),
  kindPdf: Color(0xFFC0453A),
  kindExcel: Color(0xFF17704C),
  kindWord: Color(0xFF2F62A8),
  kindText: Color(0xFF6E807B),
);

/// ส้ม-อำพัน (เข้าชุดกับระบบ RMA POS)
const paletteAmber = AppPalette(
  scaffoldBg: Color(0xFFFAF7F3),
  surface: Color(0xFFFFFFFF),
  surfaceMuted: Color(0xFFF4EEE6),
  border: Color(0xFFE8DFD2),
  textStrong: Color(0xFF231A12),
  textBody: Color(0xFF4A3D2F),
  textMuted: Color(0xFF9A8974),
  accent: Color(0xFFE0761B),
  accentSurface: Color(0xFFFCEEDE),
  onAccent: Color(0xFFFFFFFF),
  highlight: Color(0xFFFFE2A0),
  success: Color(0xFF2F8F5F),
  warning: Color(0xFFBF7E12),
  danger: Color(0xFFC6452F),
  kindPdf: Color(0xFFC03A2E),
  kindExcel: Color(0xFF1F7049),
  kindWord: Color(0xFF2C5EA6),
  kindText: Color(0xFF8A7B68),
);

/// โหมดมืด — พื้นกรมเทา + accent indigo สว่าง
const paletteDark = AppPalette(
  scaffoldBg: Color(0xFF13151B),
  surface: Color(0xFF1B1E26),
  surfaceMuted: Color(0xFF232733),
  border: Color(0xFF2F3440),
  textStrong: Color(0xFFF1F3F8),
  textBody: Color(0xFFC7CDDA),
  textMuted: Color(0xFF8891A3),
  accent: Color(0xFF6D83F2),
  accentSurface: Color(0xFF252C45),
  onAccent: Color(0xFF0F1118),
  highlight: Color(0xFF6A5A22),
  success: Color(0xFF45B183),
  warning: Color(0xFFD7A33C),
  danger: Color(0xFFE2695A),
  kindPdf: Color(0xFFE2756A),
  kindExcel: Color(0xFF5CBF92),
  kindWord: Color(0xFF7CA6F0),
  kindText: Color(0xFF9AA3B5),
);

/// ธีมที่เลือกได้ในหน้าตั้งค่า — เพิ่มธีมใหม่ = เพิ่มที่นี่ที่เดียว
class ThemeOption {
  const ThemeOption({required this.id, required this.name, required this.palette});

  final String id;
  final String name;
  final AppPalette palette;
}

const kThemeOptions = <ThemeOption>[
  ThemeOption(id: 'indigo', name: 'น้ำเงิน-อินดิโก', palette: paletteIndigo),
  ThemeOption(id: 'violet', name: 'ม่วงลาเวนเดอร์', palette: paletteViolet),
  ThemeOption(id: 'teal', name: 'เขียวมรกต', palette: paletteTeal),
  ThemeOption(id: 'amber', name: 'ส้มอำพัน', palette: paletteAmber),
  ThemeOption(id: 'dark', name: 'โหมดมืด', palette: paletteDark),
];

const kDefaultThemeId = 'indigo';

ThemeOption themeOptionOf(String id) =>
    kThemeOptions.firstWhere((t) => t.id == id, orElse: () => kThemeOptions.first);

AppPalette activePalette = paletteIndigo;

/// id ของธีมที่ใช้อยู่ — MaterialApp ฟังตัวนี้เพื่อ rebuild ทั้งแอปตอนสลับธีม
final themeNotifier = ValueNotifier<String>(kDefaultThemeId);

bool get isDarkTheme => themeNotifier.value == 'dark';

void applyTheme(String id) {
  final option = themeOptionOf(id);
  activePalette = option.palette;
  themeNotifier.value = option.id;
}

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
  static Color get kindPdf => activePalette.kindPdf;
  static Color get kindExcel => activePalette.kindExcel;
  static Color get kindWord => activePalette.kindWord;
  static Color get kindText => activePalette.kindText;
}
