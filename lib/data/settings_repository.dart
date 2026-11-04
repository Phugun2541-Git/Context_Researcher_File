import 'package:sqlite3/sqlite3.dart';

import '../domain/app_settings.dart';
import '../domain/models.dart';
import 'db.dart';

/// อ่าน/เขียนค่าตั้งค่าแบบ key-value ในตาราง app_setting
class SettingsRepository {
  SettingsRepository(this._db);

  final AppDb _db;
  Database get _c => _db.db;

  static const _keyTheme = 'theme_id';
  static const _keyFontScale = 'font_scale';
  static const _keyReduceMotion = 'reduce_motion';
  static const _keyKinds = 'enabled_kinds';
  static const _keyMaxFileSizeMb = 'max_file_size_mb';

  AppSettings load() {
    final rows = _c.select('SELECT key, value FROM app_setting');
    final map = {for (final r in rows) r['key'] as String: r['value'] as String};
    const fallback = AppSettings();

    final kinds = map[_keyKinds]
        ?.split(',')
        .map((name) => FileKind.values.where((k) => k.name == name))
        .expand((e) => e)
        .toSet();

    return AppSettings(
      themeId: map[_keyTheme] ?? fallback.themeId,
      fontScale: double.tryParse(map[_keyFontScale] ?? '') ?? fallback.fontScale,
      reduceMotion: map[_keyReduceMotion] == '1',
      enabledKinds:
          kinds == null || kinds.isEmpty ? fallback.enabledKinds : kinds,
      maxFileSizeMb:
          int.tryParse(map[_keyMaxFileSizeMb] ?? '') ?? fallback.maxFileSizeMb,
    );
  }

  void save(AppSettings settings) {
    final values = <String, String>{
      _keyTheme: settings.themeId,
      _keyFontScale: settings.fontScale.toString(),
      _keyReduceMotion: settings.reduceMotion ? '1' : '0',
      _keyKinds: settings.enabledKinds.map((k) => k.name).join(','),
      _keyMaxFileSizeMb: settings.maxFileSizeMb.toString(),
    };
    final stmt = _c.prepare(
      'INSERT INTO app_setting(key, value) VALUES (?, ?) '
      'ON CONFLICT(key) DO UPDATE SET value = excluded.value',
    );
    try {
      values.forEach((key, value) => stmt.execute([key, value]));
    } finally {
      stmt.dispose();
    }
  }
}
