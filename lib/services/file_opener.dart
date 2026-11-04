import 'dart:io';

/// เปิดไฟล์ด้วยโปรแกรมเริ่มต้นของ Windows
///
/// กรณีผู้ใช้เปิดไฟล์นั้นค้างอยู่ Windows/Excel จะเด้งเตือน read-only ให้เอง
/// ระบบนี้จึงไม่ล็อกไฟล์เองและไม่ต้องเช็คซ้ำ
class FileOpener {
  static Future<String?> open(String path) async {
    if (!File(path).existsSync()) return 'ไม่พบไฟล์: $path';
    try {
      if (Platform.isWindows) {
        // start ผ่าน cmd เพื่อให้ shell เลือกโปรแกรมตามนามสกุล (arg ว่าง = title ของหน้าต่าง)
        final r = await Process.run('cmd', ['/c', 'start', '', path]);
        return r.exitCode == 0 ? null : 'เปิดไฟล์ไม่สำเร็จ: ${r.stderr}';
      }
      if (Platform.isMacOS) {
        await Process.run('open', [path]);
        return null;
      }
      await Process.run('xdg-open', [path]);
      return null;
    } catch (e) {
      return 'เปิดไฟล์ไม่สำเร็จ: $e';
    }
  }

  /// เปิด Explorer แล้วเลือกไฟล์นั้นไว้
  static Future<void> revealInExplorer(String path) async {
    if (Platform.isWindows) {
      await Process.run('explorer', ['/select,', path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', ['-R', path]);
    } else {
      await Process.run('xdg-open', [File(path).parent.path]);
    }
  }
}
