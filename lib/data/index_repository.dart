import 'package:sqlite3/sqlite3.dart';

import '../domain/models.dart';
import '../services/match_util.dart';
import 'db.dart';

/// เขียน/อ่าน index ของเนื้อหาไฟล์
class IndexRepository {
  IndexRepository(this._db);

  final AppDb _db;
  Database get _c => _db.db;

  /// ไฟล์ที่ index ไว้แล้ว → ใช้เทียบ mtime/size ว่าต้อง reindex ไหม
  Map<String, ({int mtimeMs, int size})> indexedFingerprints(int projectId) {
    final rows = _c.select(
      'SELECT path, mtime_ms, size FROM source_file WHERE project_id = ?',
      [projectId],
    );
    return {
      for (final r in rows)
        r['path'] as String: (
          mtimeMs: r['mtime_ms'] as int,
          size: r['size'] as int,
        ),
    };
  }

  /// แทนที่ข้อมูลของไฟล์ 1 ไฟล์ทั้งก้อน (ลบ chunk เดิมแล้วใส่ใหม่) ใน transaction เดียว
  void replaceFile({
    required int projectId,
    required String path,
    required FileKind kind,
    required int mtimeMs,
    required int size,
    required ExtractResult result,
  }) {
    _c.execute('BEGIN');
    try {
      _c.execute(
        'DELETE FROM source_file WHERE project_id = ? AND path = ?',
        [projectId, path],
      );
      _c.execute('''
        INSERT INTO source_file(project_id, path, kind, mtime_ms, size, status, note, indexed_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        projectId,
        path,
        kind.name,
        mtimeMs,
        size,
        result.status.name,
        result.note,
        DateTime.now().toIso8601String(),
      ]);
      final fileId = _c.lastInsertRowId;
      final stmt = _c.prepare(
        'INSERT INTO chunk(file_id, locator, text) VALUES (?, ?, ?)',
      );
      try {
        for (final chunk in result.chunks) {
          if (chunk.text.trim().isEmpty) continue;
          stmt.execute([fileId, chunk.locator.toJson(), chunk.text]);
        }
      } finally {
        stmt.dispose();
      }
      _c.execute('COMMIT');
    } catch (_) {
      _c.execute('ROLLBACK');
      rethrow;
    }
  }

  /// ลบไฟล์ที่หายไปจากดิสก์ออกจาก index
  void removeMissing(int projectId, Set<String> existingPaths) {
    final rows = _c.select(
      'SELECT id, path FROM source_file WHERE project_id = ?',
      [projectId],
    );
    for (final r in rows) {
      if (!existingPaths.contains(r['path'] as String)) {
        _c.execute('DELETE FROM source_file WHERE id = ?', [r['id'] as int]);
      }
    }
  }

  /// ไฟล์ที่ index แล้วแต่ไม่มี text (PDF สแกน) — แสดงเตือนในผลค้นหา
  List<FileResult> problemFiles(int projectId) {
    final rows = _c.select('''
      SELECT path, kind, status, note, mtime_ms FROM source_file
      WHERE project_id = ? AND status <> 'ok'
      ORDER BY path
    ''', [projectId]);
    return rows
        .map((r) => FileResult(
              path: r['path'] as String,
              kind: FileKind.values.firstWhere((k) => k.name == r['kind']),
              hits: const [],
              totalHits: 0,
              status: FileStatus.values
                  .firstWhere((s) => s.name == r['status'] as String),
              note: r['note'] as String?,
              mtimeMs: r['mtime_ms'] as int? ?? 0,
            ))
        .toList();
  }

  /// ล้าง index ของทุกโปรเจค (ไม่ลบตัวโปรเจคและโฟลเดอร์ที่ผูกไว้)
  void clearAllIndex() {
    _c.execute('DELETE FROM source_file');
  }

  int chunkCount(int projectId) => _c.select('''
        SELECT COUNT(*) AS c FROM chunk c
        JOIN source_file f ON f.id = c.file_id
        WHERE f.project_id = ?
      ''', [projectId]).first['c'] as int;

  /// ค้นในโปรเจคที่ index ไว้ — เร็วระดับ ms
  ///
  /// [hitsPerFile] = จำนวน chip ที่เก็บต่อไฟล์ (นับ total แยก)
  List<FileResult> search({
    required int projectId,
    required String query,
    int hitsPerFile = 50,
    int maxRows = 5000,
  }) {
    final q = query.trim();
    if (q.isEmpty) return const [];

    final ResultSet rows;
    if (_db.hasTrigram && canUseFts(q)) {
      rows = _c.select('''
        SELECT f.path AS path, f.kind AS kind, f.status AS status, f.note AS note,
               f.mtime_ms AS mtime_ms, c.locator AS locator, c.text AS text
        FROM chunk_fts
        JOIN chunk c ON c.id = chunk_fts.rowid
        JOIN source_file f ON f.id = c.file_id
        WHERE chunk_fts MATCH ? AND f.project_id = ?
        LIMIT ?
      ''', [toFtsPhrase(q), projectId, maxRows]);
    } else {
      rows = _c.select('''
        SELECT f.path AS path, f.kind AS kind, f.status AS status, f.note AS note,
               f.mtime_ms AS mtime_ms, c.locator AS locator, c.text AS text
        FROM chunk c
        JOIN source_file f ON f.id = c.file_id
        WHERE f.project_id = ? AND c.text LIKE ? ESCAPE '\\'
        LIMIT ?
      ''', [projectId, toLikePattern(q), maxRows]);
    }

    return groupRowsToResults(rows, q, hitsPerFile: hitsPerFile);
  }

  /// รวมแถวดิบเป็นผลต่อไฟล์ + สร้าง snippet/offset สำหรับ highlight
  static List<FileResult> groupRowsToResults(
    Iterable<Row> rows,
    String query, {
    int hitsPerFile = 50,
  }) {
    final byPath = <String, _Acc>{};
    for (final r in rows) {
      final path = r['path'] as String;
      final text = r['text'] as String;
      final occurrences = findOccurrences(text, query);
      if (occurrences.isEmpty) continue; // trigram อาจคืน false positive
      final acc = byPath.putIfAbsent(
        path,
        () => _Acc(
          kind: FileKind.values.firstWhere((k) => k.name == r['kind']),
          status: FileStatus.values
              .firstWhere((s) => s.name == (r['status'] as String? ?? 'ok')),
          note: r['note'] as String?,
          mtimeMs: r['mtime_ms'] as int? ?? 0,
        ),
      );
      final locator = Locator.fromJson(r['locator'] as String);
      acc.total += occurrences.length;
      if (acc.hits.length < hitsPerFile) {
        acc.hits.add(buildHit(
          locator: locator,
          text: text,
          matchIndex: occurrences.first,
          matchLength: query.length,
        ));
      }
    }

    final results = byPath.entries
        .map((e) => FileResult(
              path: e.key,
              kind: e.value.kind,
              hits: e.value.hits,
              totalHits: e.value.total,
              status: e.value.status,
              note: e.value.note,
              mtimeMs: e.value.mtimeMs,
            ))
        .toList()
      ..sort((a, b) {
        final byHits = b.totalHits.compareTo(a.totalHits);
        return byHits != 0 ? byHits : a.fileName.compareTo(b.fileName);
      });
    return results;
  }
}

class _Acc {
  _Acc({required this.kind, required this.status, this.note, this.mtimeMs = 0});

  final FileKind kind;
  final FileStatus status;
  final String? note;
  final int mtimeMs;
  final List<SearchHit> hits = [];
  int total = 0;
}
