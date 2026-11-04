import 'models.dart';

/// ค่าตั้งค่าที่ผู้ใช้ปรับได้ในหน้า "ตั้งค่า" (เก็บลงตาราง app_setting)
class AppSettings {
  const AppSettings({
    this.themeId = 'indigo',
    this.fontScale = 1.0,
    this.reduceMotion = false,
    this.enabledKinds = const {
      FileKind.pdf,
      FileKind.xlsx,
      FileKind.docx,
      FileKind.text,
    },
    this.maxFileSizeMb = 64,
  });

  final String themeId;

  /// ตัวคูณขนาดตัวอักษรทั้งแอป (0.9 / 1.0 / 1.15)
  final double fontScale;

  /// ปิดเอฟเฟกต์เคลื่อนไหว (เครื่องช้า หรือผู้ใช้ไม่ชอบ)
  final bool reduceMotion;

  /// ชนิดไฟล์ที่จะอ่าน — ตัดชนิดที่ไม่ใช้ออกทำให้ index เร็วขึ้น
  final Set<FileKind> enabledKinds;

  /// ไฟล์ใหญ่กว่านี้ข้าม (MB)
  final int maxFileSizeMb;

  AppSettings copyWith({
    String? themeId,
    double? fontScale,
    bool? reduceMotion,
    Set<FileKind>? enabledKinds,
    int? maxFileSizeMb,
  }) =>
      AppSettings(
        themeId: themeId ?? this.themeId,
        fontScale: fontScale ?? this.fontScale,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        enabledKinds: enabledKinds ?? this.enabledKinds,
        maxFileSizeMb: maxFileSizeMb ?? this.maxFileSizeMb,
      );

  int get maxFileSizeBytes => maxFileSizeMb * 1024 * 1024;
}
