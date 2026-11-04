import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// เปิด/สร้าง DB + ไล่ migration ตาม PRAGMA user_version
///
/// ที่อยู่ไฟล์ (Windows): %APPDATA%/<org>/<app>/index.db
class AppDb {
  AppDb._(this.db, {required this.hasTrigram, required this.path});

  final Database db;
  final String path;

  /// sqlite ที่ bundle มารองรับ FTS5 trigram ไหม (ไทยไม่มีช่องว่าง ต้องใช้ trigram)
  /// ถ้าไม่รองรับ ระบบจะ fallback เป็น LIKE ทั้งหมด (ช้ากว่าแต่ผลเหมือนกัน)
  final bool hasTrigram;

  static AppDb? _instance;
  static AppDb get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('AppDb ยังไม่ได้ open() — เรียก AppDb.open() ใน main ก่อน');
    }
    return i;
  }

  static Future<AppDb> open({String? overridePath}) async {
    final dbPath = overridePath ?? await _defaultPath();
    if (overridePath == null) {
      Directory(p.dirname(dbPath)).createSync(recursive: true);
    }
    final db = sqlite3.open(dbPath);
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA synchronous = NORMAL');
    db.execute('PRAGMA foreign_keys = ON');

    final hasTrigram = _probeTrigram(db);
    _migrate(db, hasTrigram: hasTrigram);

    final instance = AppDb._(db, hasTrigram: hasTrigram, path: dbPath);
    _instance = instance;
    return instance;
  }

  static Future<String> _defaultPath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'index.db');
  }

  static bool _probeTrigram(Database db) {
    try {
      db.execute(
        "CREATE VIRTUAL TABLE temp.__probe USING fts5(x, tokenize='trigram')",
      );
      db.execute('DROP TABLE temp.__probe');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // migration: ต่อบล็อกใหม่ท้าย _steps เท่านั้น · step ที่ปล่อยแล้วห้ามแก้
  // ─────────────────────────────────────────────────────────────
  static final List<void Function(Database db, bool hasTrigram)> _steps = [
    // step 1 — schema ตั้งต้น
    (db, hasTrigram) {
      db.execute('''
        CREATE TABLE project (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          name       TEXT NOT NULL,
          created_at TEXT NOT NULL,
          last_indexed_at TEXT
        )
      ''');
      db.execute('''
        CREATE TABLE project_root (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          project_id INTEGER NOT NULL REFERENCES project(id) ON DELETE CASCADE,
          path       TEXT NOT NULL,
          is_file    INTEGER NOT NULL DEFAULT 0,
          UNIQUE(project_id, path)
        )
      ''');
      db.execute('''
        CREATE TABLE source_file (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          project_id INTEGER NOT NULL REFERENCES project(id) ON DELETE CASCADE,
          path       TEXT NOT NULL,
          kind       TEXT NOT NULL,
          mtime_ms   INTEGER NOT NULL,
          size       INTEGER NOT NULL,
          status     TEXT NOT NULL DEFAULT 'ok',
          note       TEXT,
          indexed_at TEXT NOT NULL,
          UNIQUE(project_id, path)
        )
      ''');
      db.execute('''
        CREATE TABLE chunk (
          id      INTEGER PRIMARY KEY AUTOINCREMENT,
          file_id INTEGER NOT NULL REFERENCES source_file(id) ON DELETE CASCADE,
          locator TEXT NOT NULL,
          text    TEXT NOT NULL
        )
      ''');
      db.execute('CREATE INDEX idx_chunk_file ON chunk(file_id)');

      if (hasTrigram) {
        // external content: เก็บข้อความจริงที่ chunk อยู่แล้ว ไม่ซ้ำซ้อน
        db.execute('''
          CREATE VIRTUAL TABLE chunk_fts USING fts5(
            text,
            content='chunk',
            content_rowid='id',
            tokenize='trigram'
          )
        ''');
        db.execute('''
          CREATE TRIGGER chunk_ai AFTER INSERT ON chunk BEGIN
            INSERT INTO chunk_fts(rowid, text) VALUES (new.id, new.text);
          END
        ''');
        db.execute('''
          CREATE TRIGGER chunk_ad AFTER DELETE ON chunk BEGIN
            INSERT INTO chunk_fts(chunk_fts, rowid, text)
            VALUES ('delete', old.id, old.text);
          END
        ''');
      } else {
        // ไม่มี trigram → ค้นด้วย LIKE บน chunk.text ตรง ๆ
        db.execute('CREATE INDEX idx_chunk_text ON chunk(text)');
      }
    },
  ];

  static void _migrate(Database db, {required bool hasTrigram}) {
    final current = db.select('PRAGMA user_version').first.values.first as int;
    for (var i = current; i < _steps.length; i++) {
      db.execute('BEGIN');
      try {
        _steps[i](db, hasTrigram);
        db.execute('PRAGMA user_version = ${i + 1}');
        db.execute('COMMIT');
      } catch (e) {
        db.execute('ROLLBACK');
        rethrow;
      }
    }
  }

  void dispose() {
    db.dispose();
    if (_instance == this) _instance = null;
  }
}
