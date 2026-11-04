import 'package:sqlite3/sqlite3.dart';

import '../domain/models.dart';
import 'db.dart';

/// ไฟล์ที่เพิ่งเปิดล่าสุด — เก็บแค่ path/ชนิด/คำค้น ไม่เก็บเนื้อหาไฟล์
class RecentRepository {
  RecentRepository(this._db);

  /// เก็บไม่เกินเท่านี้ ที่เหลือลบทิ้งอัตโนมัติ
  static const keepCount = 20;

  final AppDb _db;
  Database get _c => _db.db;

  void touch({required String path, required FileKind kind, String? query}) {
    _c.execute(
      '''
      INSERT INTO recent_file (path, kind, query, opened_at) VALUES (?, ?, ?, ?)
      ON CONFLICT(path) DO UPDATE SET kind = excluded.kind,
                                      query = excluded.query,
                                      opened_at = excluded.opened_at
      ''',
      [path, kind.name, query, DateTime.now().toIso8601String()],
    );
    _c.execute(
      '''
      DELETE FROM recent_file WHERE path NOT IN (
        SELECT path FROM recent_file ORDER BY opened_at DESC LIMIT ?
      )
      ''',
      [keepCount],
    );
  }

  List<RecentFile> list({int limit = keepCount}) => _c
      .select('SELECT path, kind, query, opened_at FROM recent_file ORDER BY opened_at DESC LIMIT ?', [limit])
      .map(
        (r) => RecentFile(
          path: r['path'] as String,
          kind: FileKind.values.firstWhere(
            (k) => k.name == r['kind'],
            orElse: () => FileKind.text,
          ),
          query: r['query'] as String?,
          openedAt: DateTime.parse(r['opened_at'] as String),
        ),
      )
      .toList();

  void clear() => _c.execute('DELETE FROM recent_file');
}
