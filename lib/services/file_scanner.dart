import 'dart:io';

import 'package:path/path.dart' as p;

import '../domain/models.dart';

/// ไฟล์ 1 รายการที่พร้อม index
class ScannedFile {
  const ScannedFile({
    required this.path,
    required this.kind,
    required this.size,
    required this.mtimeMs,
  });

  final String path;
  final FileKind kind;
  final int size;
  final int mtimeMs;
}

/// ขนาดไฟล์สูงสุดที่ยอม extract (ใหญ่กว่านี้ข้าม + บันทึกเหตุผล)
const kMaxFileSizeBytes = 64 * 1024 * 1024;

/// เดินโฟลเดอร์/ไฟล์ที่ผู้ใช้ระบุ แล้วคืนเฉพาะไฟล์ชนิดที่รองรับ
///
/// ต้องมี root อย่างน้อย 1 รายการเสมอ — ระบบไม่มีโหมดค้นทั้งเครื่อง
class FileScanner {
  const FileScanner({this.skipHidden = true});

  final bool skipHidden;

  Future<List<ScannedFile>> scan(List<String> roots) async {
    final out = <ScannedFile>[];
    final seen = <String>{};
    for (final root in roots) {
      final type = FileSystemEntity.typeSync(root);
      if (type == FileSystemEntityType.file) {
        final f = _toScanned(File(root));
        if (f != null && seen.add(f.path)) out.add(f);
      } else if (type == FileSystemEntityType.directory) {
        await for (final entity in Directory(root).list(
          recursive: true,
          followLinks: false,
        ).handleError((_) {}, test: (e) => e is FileSystemException)) {
          if (entity is! File) continue;
          if (skipHidden && _isHiddenPath(entity.path)) continue;
          final f = _toScanned(entity);
          if (f != null && seen.add(f.path)) out.add(f);
        }
      }
    }
    out.sort((a, b) => a.path.compareTo(b.path));
    return out;
  }

  ScannedFile? _toScanned(File file) {
    final kind = FileKind.fromExtension(p.extension(file.path));
    if (kind == null) return null;
    final name = p.basename(file.path);
    if (name.startsWith('~\$')) return null; // ไฟล์ lock ของ Office
    try {
      final stat = file.statSync();
      return ScannedFile(
        path: file.path,
        kind: kind,
        size: stat.size,
        mtimeMs: stat.modified.millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  bool _isHiddenPath(String path) =>
      p.split(path).any((seg) => seg.startsWith('.') && seg.length > 1);
}
