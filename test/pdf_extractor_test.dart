@Tags(['pdfium'])
library;

import 'dart:io';

import 'package:context_researcher_file/domain/models.dart';
import 'package:context_researcher_file/services/extractors/pdf_extractor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

/// เทส PDF ต้องมี native PDFium
///
/// ในแอปจริง (Windows build) PDFium มาพร้อม pdfrx อัตโนมัติ แต่ใน `flutter test`
/// ไม่มี native asset ให้ → ต้องชี้ไฟล์เองด้วย env `PDFIUM_MODULE_PATH` ก่อนรัน:
///   flutter test test/pdf_extractor_test.dart --tags pdfium
void main() {
  final modulePath = Platform.environment['PDFIUM_MODULE_PATH'];
  final skipReason = modulePath == null || !File(modulePath).existsSync()
      ? 'ไม่มี libpdfium (ตั้ง PDFIUM_MODULE_PATH ก่อนรัน) — เทส PDF บนแอปจริงแทน'
      : null;

  setUpAll(() async {
    if (skipReason != null) return;
    Pdfrx.pdfiumModulePath = modulePath;
    await pdfrxInitialize(tmpPath: Directory.systemTemp.path);
  });

  test('pdf: ดึง text ได้พร้อมเลขหน้า', () async {
    final result = await PdfExtractor().extract('test/fixtures_pdf/sample.pdf');
    expect(result.status, FileStatus.ok);
    expect(result.chunks.any((c) => c.text.contains('RMA Service Manual')), isTrue);

    final page2 = result.chunks.where((c) => c.locator.page == 2);
    expect(page2.isNotEmpty, isTrue);
    expect(page2.any((c) => c.text.contains('Warranty')), isTrue);
  }, skip: skipReason);

  test('pdf สแกน (ไม่มี text layer) → noText ไม่ใช่ error', () async {
    final result =
        await PdfExtractor().extract('test/fixtures_pdf/scanned_no_text.pdf');
    expect(result.status, FileStatus.noText);
    expect(result.note, contains('สแกน'));
  }, skip: skipReason);
}
