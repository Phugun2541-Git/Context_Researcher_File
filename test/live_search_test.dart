import 'package:context_researcher_file/data/db.dart';
import 'package:context_researcher_file/data/index_repository.dart';
import 'package:context_researcher_file/domain/models.dart';
import 'package:context_researcher_file/services/file_scanner.dart';
import 'package:context_researcher_file/services/search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';

/// เทส flow ค้นหาแบบไม่ผูกโปรเจค (scan สด) บนโฟลเดอร์ fixtures จริง
void main() {
  test('scanner เก็บเฉพาะชนิดไฟล์ที่รองรับ', () async {
    final files = await const FileScanner().scan(['test/fixtures']);
    expect(files.map((f) => f.kind).toSet(),
        {FileKind.xlsx, FileKind.docx, FileKind.text});
    expect(files.every((f) => f.size > 0), isTrue);
  });

  test(r'scanner ข้ามไฟล์ lock ของ Office (~$...) และนามสกุลที่ไม่รองรับ', () async {
    final tmp = Directory.systemTemp.createTempSync('crf_scan');
    try {
      File('${tmp.path}/~\$งาน.xlsx').writeAsStringSync('lock');
      File('${tmp.path}/รูป.png').writeAsStringSync('img');
      File('${tmp.path}/จริง.txt').writeAsStringSync('RMA');
      final files = await const FileScanner().scan([tmp.path]);
      expect(files.length, 1);
      expect(files.first.path, endsWith('จริง.txt'));
    } finally {
      tmp.deleteSync(recursive: true);
    }
  });

  test('ค้นสด: ทยอยส่งผล + รวมทุกชนิดไฟล์ที่พบคำ', () async {
    final tmp = Directory.systemTemp.createTempSync('crf_live');
    final db = await AppDb.open(overridePath: '${tmp.path}/index.db');
    addTearDown(() {
      db.dispose();
      tmp.deleteSync(recursive: true);
    });

    final service = SearchService(indexRepo: IndexRepository(db));
    final events = await service
        .searchLive(roots: ['test/fixtures'], query: 'RMA')
        .toList();

    expect(events.first.progress.total, greaterThan(2));
    expect(events.last.progress.finished, isTrue);

    final results = events.last.results;
    final kinds = results.where((r) => r.totalHits > 0).map((r) => r.kind).toSet();
    expect(kinds, containsAll({FileKind.xlsx, FileKind.docx, FileKind.text}));

    // เรียงไฟล์ที่เจอมากสุดขึ้นก่อน
    final hitCounts = results.map((r) => r.totalHits).toList();
    final sorted = [...hitCounts]..sort((a, b) => b.compareTo(a));
    expect(hitCounts, sorted);

    // locator ของ Excel ต้องเป็น cell ref จริง
    final xlsx = results.firstWhere((r) => r.kind == FileKind.xlsx);
    expect(xlsx.hits.first.locator.cell, isNotNull);
  });

  test('ค้นสด: ไม่พบคำ = ไม่มีผล (ไม่นับไฟล์ที่อ่านได้แต่ไม่มีคำ)', () async {
    final tmp = Directory.systemTemp.createTempSync('crf_live2');
    final db = await AppDb.open(overridePath: '${tmp.path}/index.db');
    addTearDown(() {
      db.dispose();
      tmp.deleteSync(recursive: true);
    });
    final service = SearchService(indexRepo: IndexRepository(db));
    final events = await service
        .searchLive(roots: ['test/fixtures'], query: 'คำที่ไม่มีจริงในเอกสาร')
        .toList();
    expect(events.last.results, isEmpty);
  });

  test('ค้นสด: ไม่มี root = ไม่ทำอะไรเลย (กันวิ่งทั้งเครื่อง)', () async {
    final tmp = Directory.systemTemp.createTempSync('crf_live3');
    final db = await AppDb.open(overridePath: '${tmp.path}/index.db');
    addTearDown(() {
      db.dispose();
      tmp.deleteSync(recursive: true);
    });
    final service = SearchService(indexRepo: IndexRepository(db));
    expect(
      await service.searchLive(roots: const [], query: 'RMA').toList(),
      isEmpty,
    );
  });
}
