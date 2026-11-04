import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ThemeData กลาง — ดึงค่าจาก AppColors ทั้งหมด
/// ฟอนต์หลัก bundle มากับแอป (ไทย+ละติน) — ไม่พึ่งฟอนต์ของเครื่องเพื่อให้หน้าตาเหมือนกันทุกเครื่อง
const kFontFamily = 'Anuphan';

/// มุมโค้งเต็มใบของ ThemeData (ที่นี่ไม่มี context จึงใช้ค่าคงที่แทน D.radiusPill)
const kPillRadius = 999.0;

ThemeData buildAppTheme() {
  final base = isDarkTheme
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);
  return base.copyWith(
    // ตั้งที่ ThemeData เพื่อให้ widget ที่ไม่ได้ระบุ style เองได้ฟอนต์เดียวกันหมด
    scaffoldBackgroundColor: AppColors.scaffoldBg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      surface: AppColors.surface,
      outlineVariant: AppColors.border,
      error: AppColors.danger,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: kFontFamily,
      bodyColor: AppColors.textBody,
      displayColor: AppColors.textStrong,
    ),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: kFontFamily),
    dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1),
    // ช่องกรอกทรง pill พื้นเทาอ่อนไม่มีขอบ — เห็นขอบเฉพาะตอน focus
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceMuted,
      hintStyle: TextStyle(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kPillRadius),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kPillRadius),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kPillRadius),
        borderSide: BorderSide(color: AppColors.accent, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textBody,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: AppColors.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.textBody,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.textStrong,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(color: AppColors.surface, fontSize: 12),
    ),
  );
}
