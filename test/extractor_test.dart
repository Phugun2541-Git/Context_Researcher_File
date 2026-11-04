import 'dart:io';

import 'package:context_researcher_file/domain/models.dart';
import 'package:context_researcher_file/services/extractors/docx_extractor.dart';
import 'package:context_researcher_file/services/extractors/text_extractor.dart';
import 'package:context_researcher_file/services/extractors/xlsx_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

/// เทส extractor กับไฟล์จริงใน test/fixtures
/// (PDF ต้องเทสบนแอปจริงเพราะ PDFium ไม่ init ใน flutter test)
void main() {
  test('xlsx: ได้ sheet + cell ref ตรงตำแหน่ง', () async {
    final result = await XlsxExtractor().extract('test/fixtures/sample.xlsx');
    expect(result.status, FileStatus.ok);

    final b12 = result.chunks.where((c) =>
        c.locator.sheet == 'ใบเสนอราคา' && c.locator.cell == 'B12');
    expect(b12.length, 1);
    expect(b12.first.text, contains('รับประกัน'));

    // sheet ที่ 2 ต้องถูกอ่านด้วย
    final note = result.chunks.where((c) => c.locator.sheet == 'หมายเหตุ');
    expect(note.length, 1);
    expect(note.first.locator.cell, 'A3');

    // ตัวเลขต้องกลายเป็นข้อความที่ค้นได้
    final price = result.chunks.where((c) => c.locator.cell == 'C2');
    expect(price.first.text, contains('1250'));
  });

  test('xlsx: rels relative + inlineStr + sharedStrings หลาย run + ค่าสูตร', () async {
    final result =
        await XlsxExtractor().extract('test/fixtures/sample_relative.xlsx');
    expect(result.status, FileStatus.ok);

    final byRef = {
      for (final c in result.chunks) c.locator.cell!: c,
    };
    // inlineStr
    expect(byRef['A1']!.text, 'ใบกำกับภาษี RMA');
    // sharedStrings ที่ข้อความถูกแบ่งเป็นหลาย run ต้องถูกต่อกลับเป็นก้อนเดียว
    expect(byRef['B1']!.text, 'คำที่แยก run กัน RMA');
    // ตัวเลขดิบ
    expect(byRef['C5']!.text, '2540.5');
    // สูตร: เก็บค่าที่คำนวณไว้ ไม่เก็บตัวสูตร
    expect(byRef['D5']!.text, 'ผลสูตร RMA');
    expect(byRef['D5']!.text.contains('CONCAT'), isFalse);
    // ชื่อ sheet + เลขแถวจาก ref
    expect(result.chunks.first.locator.sheet, 'รายการ');
    expect(byRef['C5']!.locator.row, 5);
  });

  test('normalizeTarget: รองรับ path ทุกแบบใน rels', () {
    expect(normalizeTarget('/xl/worksheets/sheet1.xml'), 'xl/worksheets/sheet1.xml');
    expect(normalizeTarget('worksheets/sheet2.xml'), 'xl/worksheets/sheet2.xml');
    expect(normalizeTarget('../worksheets/sheet3.xml'), 'xl/worksheets/sheet3.xml');
    expect(normalizeTarget(r'worksheets\sheet4.xml'), 'xl/worksheets/sheet4.xml');
  });

  test('columnLetter: แปลง index เป็นตัวอักษรแบบ Excel', () {
    expect(columnLetter(0), 'A');
    expect(columnLetter(25), 'Z');
    expect(columnLetter(26), 'AA');
    expect(columnLetter(27), 'AB');
    expect(columnLetter(701), 'ZZ');
    expect(columnLetter(702), 'AAA');
  });

  test('docx: ได้ข้อความต่อย่อหน้า ข้ามย่อหน้าว่าง', () async {
    final result = await DocxExtractor().extract('test/fixtures/sample.docx');
    expect(result.status, FileStatus.ok);
    expect(result.chunks.length, 4); // หัวเรื่อง + 2 ขั้นตอน + หมายเหตุ (ย่อหน้าว่างถูกข้าม)
    expect(result.chunks.first.text, contains('คู่มือการเคลม RMA'));
    expect(result.chunks.last.locator.paragraph, 4);
    expect(
      result.chunks.any((c) => c.text.contains('ขั้นตอนที่ 2')),
      isTrue,
    );
  });

  test('docxParagraphs: ถอด entity และรวม run ในย่อหน้าเดียวกัน', () {
    const xml = '<w:p><w:r><w:t>ราคา &lt; 100</w:t></w:r>'
        '<w:r><w:t xml:space="preserve"> บาท</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>  </w:t></w:r></w:p>';
    expect(docxParagraphs(xml), ['ราคา < 100 บาท']);
  });

  test('text: locator = เลขบรรทัดจริง (นับบรรทัดว่างด้วย)', () async {
    final result = await TextExtractor().extract('test/fixtures/sample.txt');
    expect(result.status, FileStatus.ok);
    expect(result.chunks.length, 3);
    expect(result.chunks[1].locator.line, 3);
    expect(result.chunks[1].text, contains('RMA'));
  });

  test('ไฟล์ที่ไม่มีอยู่ → status error ไม่โยน exception', () async {
    final result = await TextExtractor().extract('test/fixtures/__none__.txt');
    expect(result.status, FileStatus.error);
    expect(result.note, isNotNull);
  });

  test('decodeTextBytes: utf8 ไทยอ่านได้ตรง', () {
    final bytes = File('test/fixtures/sample.txt').readAsBytesSync();
    expect(decodeTextBytes(bytes), contains('บรรทัดแรก'));
  });
}
