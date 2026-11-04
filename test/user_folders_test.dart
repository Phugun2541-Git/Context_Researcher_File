import 'dart:io';

import 'package:context_researcher_file/domain/models.dart';
import 'package:context_researcher_file/services/file_scanner.dart';
import 'package:context_researcher_file/services/user_folders.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scanner ตัดทั้งกิ่งของโฟลเดอร์ระบบ/แคช แต่ยังเก็บเอกสารปกติ', () async {
    final tmp = Directory.systemTemp.createTempSync('crf_skip');
    addTearDown(() => tmp.deleteSync(recursive: true));

    File('${tmp.path}/รายงาน.txt').writeAsStringSync('ok');
    for (final skipped in ['AppData', 'node_modules', 'Windows', '.git', 'Temp']) {
      Directory('${tmp.path}/$skipped').createSync();
      File('${tmp.path}/$skipped/ซ่อน.txt').writeAsStringSync('no');
    }
    Directory('${tmp.path}/งานปี 2026').createSync();
    File('${tmp.path}/งานปี 2026/สรุป.txt').writeAsStringSync('ok');

    final files = await const FileScanner().scan([tmp.path]);
    final names = files.map((f) => f.path.split(Platform.pathSeparator).last).toList();

    expect(names, containsAll(['รายงาน.txt', 'สรุป.txt']));
    expect(names, isNot(contains('ซ่อน.txt')), reason: 'โฟลเดอร์ระบบ/แคชต้องไม่ถูกเดินเลย');
    expect(files.every((f) => f.kind == FileKind.text), isTrue);
  });

  test('โฟลเดอร์เอกสารมาตรฐานคืนเฉพาะที่มีจริง และไม่ซ้อนทับกัน', () {
    final roots = UserFolders.documentRoots();
    for (final root in roots) {
      expect(Directory(root).existsSync(), isTrue);
    }
    // ไม่มี root ไหนอยู่ใต้ root อื่น (กันอ่านไฟล์เดิมซ้ำสองรอบ)
    for (final a in roots) {
      for (final b in roots) {
        if (identical(a, b)) continue;
        expect(a.startsWith('$b${Platform.pathSeparator}'), isFalse);
      }
    }
  });
}
