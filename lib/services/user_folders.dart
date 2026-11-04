import 'dart:io';

import 'package:path/path.dart' as p;

/// โฟลเดอร์เอกสารมาตรฐานของผู้ใช้บน Windows
///
/// ใช้กับโปรเจคสำเร็จรูป "ไฟล์ของฉัน" สำหรับเคสจำไม่ได้ว่าเก็บไฟล์ไว้ที่ไหน
/// — ครอบเฉพาะที่คนเก็บเอกสารจริง ไม่ใช่ทั้งไดรฟ์ (ไดรฟ์ระบบมีไฟล์หลักแสน-ล้าน
/// ซึ่งอ่านทุกไฟล์ไม่ไหวและไม่มีเอกสารของผู้ใช้อยู่)
class UserFolders {
  const UserFolders._();

  static const myFilesProjectName = 'ไฟล์ของฉัน';

  /// คืนเฉพาะโฟลเดอร์ที่มีอยู่จริงในเครื่องนี้ (ไม่ซ้ำกัน)
  static List<String> documentRoots() {
    final home =
        Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return const [];

    final oneDrive = Platform.environment['OneDrive'];
    final candidates = <String>[
      p.join(home, 'Desktop'),
      p.join(home, 'Documents'),
      p.join(home, 'Downloads'),
      if (oneDrive != null && oneDrive.isNotEmpty) oneDrive else p.join(home, 'OneDrive'),
    ];

    final out = <String>[];
    for (final path in candidates) {
      if (!Directory(path).existsSync()) continue;
      // OneDrive มักมี Desktop/Documents ซ้ำกับของเครื่อง — ตัดตัวที่อยู่ใต้ของที่เลือกไปแล้ว
      if (out.any((kept) => p.isWithin(kept, path))) continue;
      out.removeWhere((kept) => p.isWithin(path, kept));
      out.add(path);
    }
    return out;
  }
}
