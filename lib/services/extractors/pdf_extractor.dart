import 'package:pdfrx/pdfrx.dart';

import '../../domain/models.dart';
import 'extractor.dart';

/// ดึง text ของ PDF ด้วย PDFium (pdfrx)
///
/// chunk = 1 บรรทัดในหน้า · locator = เลขหน้า (viewer หา highlight เองจากคำค้น)
/// PDF สแกนที่ไม่มี text layer → คืน status noText (ไม่ OCR ตามที่เจ้าของเคาะ)
class PdfExtractor implements FileExtractor {
  @override
  FileKind get kind => FileKind.pdf;

  /// PDFium init อยู่ฝั่ง main isolate (pdfrxFlutterInitialize) → ไม่ส่งเข้า Isolate.run
  @override
  bool get isolateSafe => false;

  @override
  Future<ExtractResult> extract(String path) async {
    PdfDocument? doc;
    try {
      doc = await PdfDocument.openFile(path);
      final chunks = <Chunk>[];
      var textChars = 0;
      for (final page in doc.pages) {
        final pageText = await page.loadText();
        final full = pageText?.fullText ?? '';
        textChars += full.trim().length;
        for (final line in splitNonEmptyLines(full)) {
          if (chunks.length >= kMaxChunksPerFile) break;
          chunks.add(Chunk(locator: Locator(page: page.pageNumber), text: line));
        }
      }
      if (textChars == 0) {
        return const ExtractResult.failed(
          status: FileStatus.noText,
          note: 'PDF นี้ไม่มีชั้นข้อความ (น่าจะเป็นไฟล์สแกน) — ค้นคำไม่ได้',
        );
      }
      return ExtractResult(chunks: chunks);
    } catch (e) {
      return ExtractResult.failed(
        status: FileStatus.error,
        note: 'อ่าน PDF ไม่ได้: $e',
      );
    } finally {
      await doc?.dispose();
    }
  }
}
