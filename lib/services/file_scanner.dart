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

/// โฟลเดอร์ที่ข้ามทั้งกิ่งเสมอ — ของระบบ/แคช/ของเครื่องมือ ไม่ใช่เอกสารของผู้ใช้
/// (เทียบด้วยชื่อตัวพิมพ์เล็ก)
const kSkipDirNames = <String>{
  'appdata',
  'application data',
  'windows',
  'winsxs',
  'program files',
  'program files (x86)',
  'programdata',
  '\$recycle.bin',
  'system volume information',
  'node_modules',
  '__pycache__',
  'venv',
  '.venv',
  'onedrivetemp',
  'temp',
  'tmp',
  'cache',
  'caches',
};

/// เดินโฟลเดอร์/ไฟล์ที่ผู้ใช้ระบุ แล้วคืนเฉพาะไฟล์ชนิดที่รองรับ
///
/// ต้องมี root อย่างน้อย 1 รายการเสมอ — ระบบไม่มีโหมดค้นทั้งเครื่อง
class FileScanner {
  const FileScanner({
    this.skipHidden = true,
    this.allowedKinds,
    this.maxFileSizeBytes = kMaxFileSizeBytes,
  });

  final bool skipHidden;

  /// null = ทุกชนิดที่ระบบรองรับ · มีค่า = เฉพาะชนิดที่ผู้ใช้เปิดไว้ในหน้าตั้งค่า
  final Set<FileKind>? allowedKinds;
  final int maxFileSizeBytes;

  Future<List<ScannedFile>> scan(List<String> roots) async {
    final out = <ScannedFile>[];
    final seen = <String>{};
    for (final root in roots) {
      final type = FileSystemEntity.typeSync(root);
      if (type == FileSystemEntityType.file) {
        final f = _toScanned(File(root));
        if (f != null && seen.add(f.path)) out.add(f);
      } else if (type == FileSystemEntityType.directory) {
        await _walk(Directory(root), out, seen);
      }
    }
    out.sort((a, b) => a.path.compareTo(b.path));
    return out;
  }

  /// เดินทีละชั้นเอง (ไม่ใช้ list(recursive: true)) เพื่อ **ตัดทั้งโฟลเดอร์** ที่ไม่ต้องค้น
  /// ตั้งแต่ก่อนเข้าไปเดิน — ถ้าปล่อยให้เดินเข้า AppData/node_modules แล้วค่อยกรองทีหลัง
  /// การค้นในโฟลเดอร์ผู้ใช้จะช้าขึ้นหลายเท่าโดยไม่ได้ผลเพิ่มเลย
  Future<void> _walk(Directory dir, List<ScannedFile> out, Set<String> seen) async {
    final stack = <Directory>[dir];
    while (stack.isNotEmpty) {
      final current = stack.removeLast();
      final List<FileSystemEntity> entries;
      try {
        entries = current.listSync(followLinks: false);
      } catch (_) {
        continue; // ไม่มีสิทธิ์อ่าน/โฟลเดอร์หาย → ข้ามทั้งกิ่ง
      }
      for (final entity in entries) {
        final name = p.basename(entity.path);
        if (entity is Directory) {
          if (skipHidden && name.startsWith('.') && name.length > 1) continue;
          if (kSkipDirNames.contains(name.toLowerCase())) continue;
          stack.add(entity);
        } else if (entity is File) {
          if (skipHidden && name.startsWith('.') && name.length > 1) continue;
          final f = _toScanned(entity);
          if (f != null && seen.add(f.path)) out.add(f);
        }
      }
    }
  }

  ScannedFile? _toScanned(File file) {
    final kind = FileKind.fromExtension(p.extension(file.path));
    if (kind == null) return null;
    if (allowedKinds != null && !allowedKinds!.contains(kind)) return null;
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
}
