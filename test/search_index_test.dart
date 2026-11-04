import 'dart:io';

import 'package:context_researcher_file/data/db.dart';
import 'package:context_researcher_file/data/index_repository.dart';
import 'package:context_researcher_file/data/project_repository.dart';
import 'package:context_researcher_file/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// เทส index + ค้นหาด้วย sqlite จริง (FTS5 trigram) บนไฟล์ DB ชั่วคราว
void main() {
  late Directory tmp;
  late AppDb db;
  late ProjectRepository projects;
  late IndexRepository index;
  late int projectId;

  ExtractResult result(List<Chunk> chunks) => ExtractResult(chunks: chunks);

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('crf_test');
    db = await AppDb.open(overridePath: '${tmp.path}/index.db');
    projects = ProjectRepository(db);
    index = IndexRepository(db);
    projectId = projects.createProject('RMA');
  });

  tearDown(() {
    db.dispose();
    tmp.deleteSync(recursive: true);
  });

  test('sqlite ที่ใช้ต้องรองรับ FTS5 trigram (ไทยไม่มีช่องว่าง)', () {
    expect(db.hasTrigram, isTrue);
  });

  test('ค้นคำไทยกลางประโยคเจอ + นับจำนวนจุดถูก', () {
    index.replaceFile(
      projectId: projectId,
      path: r'C:\งาน\คู่มือ.docx',
      kind: FileKind.docx,
      mtimeMs: 1,
      size: 10,
      result: result([
        const Chunk(
          locator: Locator(paragraph: 1),
          text: 'ขั้นตอนการเคลมสินค้ารับประกันของลูกค้า',
        ),
        const Chunk(
          locator: Locator(paragraph: 4),
          text: 'การรับประกันไม่ครอบคลุมความเสียหายจากการใช้ผิดวิธี รับประกัน 1 ปี',
        ),
      ]),
    );

    final found = index.search(projectId: projectId, query: 'รับประกัน');
    expect(found.length, 1);
    expect(found.first.fileName, 'คู่มือ.docx');
    expect(found.first.totalHits, 3); // ย่อหน้า 1 ครั้งเดียว + ย่อหน้า 4 สองครั้ง
    expect(found.first.hits.map((h) => h.locator.label),
        containsAll(['ย่อหน้า 1', 'ย่อหน้า 4']));
  });

  test('snippet ชี้ตำแหน่งคำสำหรับระบายสี', () {
    index.replaceFile(
      projectId: projectId,
      path: r'C:\งาน\note.txt',
      kind: FileKind.text,
      mtimeMs: 1,
      size: 10,
      result: result([
        const Chunk(locator: Locator(line: 7), text: 'ติดต่อฝ่ายบริการ RMA เบอร์ 02-000'),
      ]),
    );
    final hit = index.search(projectId: projectId, query: 'RMA').first.hits.first;
    expect(
      hit.snippet.substring(hit.matchStart, hit.matchStart + hit.matchLength),
      'RMA',
    );
    expect(hit.locator.label, 'บรรทัด 7');
  });

  test('คำค้น 2 ตัวอักษร (trigram ใช้ไม่ได้) ต้องยัง fallback LIKE แล้วเจอ', () {
    index.replaceFile(
      projectId: projectId,
      path: r'C:\งาน\ราคา.xlsx',
      kind: FileKind.xlsx,
      mtimeMs: 1,
      size: 10,
      result: result([
        const Chunk(locator: Locator(sheet: 'Sheet1', cell: 'B2', row: 2), text: 'ยางรถ 15 นิ้ว'),
      ]),
    );
    final found = index.search(projectId: projectId, query: '15');
    expect(found.length, 1);
    expect(found.first.hits.first.locator.label, 'Sheet1!B2');
  });

  test('อักขระพิเศษของ LIKE/FTS ไม่ทำให้พัง', () {
    index.replaceFile(
      projectId: projectId,
      path: r'C:\งาน\promo.txt',
      kind: FileKind.text,
      mtimeMs: 1,
      size: 10,
      result: result([
        const Chunk(locator: Locator(line: 1), text: 'ลด 50%_ของราคา "พิเศษ"'),
      ]),
    );
    expect(index.search(projectId: projectId, query: '50%_').length, 1);
    expect(index.search(projectId: projectId, query: '"พิเศษ"').length, 1);
    expect(index.search(projectId: projectId, query: 'ไม่มีคำนี้'), isEmpty);
  });

  test('index ไฟล์เดิมซ้ำ = แทนที่ ไม่ซ้อนผล', () {
    void put(String text) => index.replaceFile(
          projectId: projectId,
          path: r'C:\งาน\a.txt',
          kind: FileKind.text,
          mtimeMs: 1,
          size: 10,
          result: result([Chunk(locator: const Locator(line: 1), text: text)]),
        );
    put('มีคำว่า RMA');
    put('มีคำว่า RMA');
    final found = index.search(projectId: projectId, query: 'RMA');
    expect(found.length, 1);
    expect(found.first.totalHits, 1);
    expect(index.chunkCount(projectId), 1);

    // แก้ไฟล์แล้วคำหายไป → ต้องค้นไม่เจออีก (chunk เก่าถูกลบจาก FTS ด้วย)
    put('ไม่มีคำนั้นแล้ว');
    expect(index.search(projectId: projectId, query: 'RMA'), isEmpty);
  });

  test('ไฟล์ที่หายจากดิสก์ถูกถอดออกจาก index', () {
    index.replaceFile(
      projectId: projectId,
      path: r'C:\งาน\หาย.txt',
      kind: FileKind.text,
      mtimeMs: 1,
      size: 10,
      result: result([const Chunk(locator: Locator(line: 1), text: 'RMA')]),
    );
    index.removeMissing(projectId, {r'C:\งาน\อื่น.txt'});
    expect(index.search(projectId: projectId, query: 'RMA'), isEmpty);
    expect(index.chunkCount(projectId), 0);
  });

  test('PDF สแกน (noText) ถูกเก็บเป็นไฟล์ที่ต้องเตือน ไม่ใช่ไฟล์ที่ไม่มีคำ', () {
    index.replaceFile(
      projectId: projectId,
      path: r'C:\งาน\สแกน.pdf',
      kind: FileKind.pdf,
      mtimeMs: 1,
      size: 10,
      result: const ExtractResult.failed(
        status: FileStatus.noText,
        note: 'PDF นี้ไม่มีชั้นข้อความ (น่าจะเป็นไฟล์สแกน) — ค้นคำไม่ได้',
      ),
    );
    final problems = index.problemFiles(projectId);
    expect(problems.length, 1);
    expect(problems.first.status, FileStatus.noText);
    expect(problems.first.note, contains('สแกน'));
  });

  test('fingerprint ใช้ตัดสินว่าไฟล์ต้อง reindex ไหม', () {
    index.replaceFile(
      projectId: projectId,
      path: r'C:\งาน\b.txt',
      kind: FileKind.text,
      mtimeMs: 111,
      size: 222,
      result: result([const Chunk(locator: Locator(line: 1), text: 'x')]),
    );
    final fp = index.indexedFingerprints(projectId);
    expect(fp[r'C:\งาน\b.txt']!.mtimeMs, 111);
    expect(fp[r'C:\งาน\b.txt']!.size, 222);
  });

  test('ค้นข้ามโปรเจคกันไม่ได้', () {
    final other = projects.createProject('อื่น');
    index.replaceFile(
      projectId: other,
      path: r'C:\อื่น\c.txt',
      kind: FileKind.text,
      mtimeMs: 1,
      size: 1,
      result: result([const Chunk(locator: Locator(line: 1), text: 'ความลับ RMA')]),
    );
    expect(index.search(projectId: projectId, query: 'ความลับ'), isEmpty);
    expect(index.search(projectId: other, query: 'ความลับ').length, 1);
  });

  test('ลบโปรเจค = index ของมันหายตามด้วย (foreign key cascade)', () {
    index.replaceFile(
      projectId: projectId,
      path: r'C:\งาน\d.txt',
      kind: FileKind.text,
      mtimeMs: 1,
      size: 1,
      result: result([const Chunk(locator: Locator(line: 1), text: 'RMA')]),
    );
    projects.deleteProject(projectId);
    expect(index.chunkCount(projectId), 0);
  });

  test('root ของโปรเจคถูกเก็บและกันซ้ำ', () {
    projects.addRoot(projectId, r'D:\งาน', isFile: false);
    projects.addRoot(projectId, r'D:\งาน', isFile: false);
    projects.addRoot(projectId, r'D:\งาน\ไฟล์.pdf', isFile: true);
    final roots = projects.listRoots(projectId);
    expect(roots.length, 2);
    expect(roots.where((r) => r.isFile).length, 1);
  });
}
