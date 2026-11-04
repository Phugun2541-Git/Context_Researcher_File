import 'package:sqlite3/sqlite3.dart';

import '../domain/models.dart';
import 'db.dart';

/// CRUD ของโปรเจค + root ที่ผูกไว้
class ProjectRepository {
  ProjectRepository(this._db);

  final AppDb _db;
  Database get _c => _db.db;

  List<Project> listProjects() {
    final rows = _c.select('''
      SELECT p.id, p.name, p.created_at, p.last_indexed_at,
             (SELECT COUNT(*) FROM source_file f WHERE f.project_id = p.id) AS file_count
      FROM project p
      ORDER BY p.name COLLATE NOCASE
    ''');
    return rows.map((r) {
      final id = r['id'] as int;
      return Project(
        id: id,
        name: r['name'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
        lastIndexedAt: r['last_indexed_at'] == null
            ? null
            : DateTime.parse(r['last_indexed_at'] as String),
        fileCount: r['file_count'] as int,
        roots: listRoots(id),
      );
    }).toList();
  }

  Project? findProject(int id) {
    final rows = _c.select('SELECT * FROM project WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    final count = _c.select(
      'SELECT COUNT(*) AS c FROM source_file WHERE project_id = ?',
      [id],
    ).first['c'] as int;
    return Project(
      id: id,
      name: r['name'] as String,
      createdAt: DateTime.parse(r['created_at'] as String),
      lastIndexedAt: r['last_indexed_at'] == null
          ? null
          : DateTime.parse(r['last_indexed_at'] as String),
      fileCount: count,
      roots: listRoots(id),
    );
  }

  List<ProjectRoot> listRoots(int projectId) {
    final rows = _c.select(
      'SELECT id, path, is_file FROM project_root WHERE project_id = ? ORDER BY path',
      [projectId],
    );
    return rows
        .map((r) => ProjectRoot(
              id: r['id'] as int,
              path: r['path'] as String,
              isFile: (r['is_file'] as int) == 1,
            ))
        .toList();
  }

  int createProject(String name) {
    _c.execute(
      'INSERT INTO project(name, created_at) VALUES (?, ?)',
      [name.trim(), DateTime.now().toIso8601String()],
    );
    return _c.lastInsertRowId;
  }

  void renameProject(int id, String name) {
    _c.execute('UPDATE project SET name = ? WHERE id = ?', [name.trim(), id]);
  }

  void deleteProject(int id) {
    _c.execute('DELETE FROM project WHERE id = ?', [id]);
  }

  /// เพิ่ม root — ซ้ำได้ (UNIQUE) จึงใช้ OR IGNORE
  void addRoot(int projectId, String path, {required bool isFile}) {
    _c.execute(
      'INSERT OR IGNORE INTO project_root(project_id, path, is_file) VALUES (?, ?, ?)',
      [projectId, path, isFile ? 1 : 0],
    );
  }

  void removeRoot(int rootId) {
    _c.execute('DELETE FROM project_root WHERE id = ?', [rootId]);
  }

  void touchIndexedAt(int projectId) {
    _c.execute(
      'UPDATE project SET last_indexed_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), projectId],
    );
  }
}
