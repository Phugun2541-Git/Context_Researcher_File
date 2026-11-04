import 'package:flutter/material.dart';

import 'app_colors.dart';

/// ThemeData กลาง — ดึงค่าจาก AppColors ทั้งหมด
/// ฟอนต์หลัก bundle มากับแอป (ไทย+ละติน) — ไม่พึ่งฟอนต์ของเครื่องเพื่อให้หน้าตาเหมือนกันทุกเครื่อง
const kFontFamily = 'Anuphan';

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
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      hintStyle: TextStyle(color: AppColors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.accent, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textBody,
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
