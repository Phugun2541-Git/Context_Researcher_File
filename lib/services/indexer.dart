import 'dart:async';
import 'dart:isolate';

import '../data/index_repository.dart';
import '../data/project_repository.dart';
import '../domain/models.dart';
import 'extractors/docx_extractor.dart';
import 'extractors/extractor.dart';
import 'extractors/pdf_extractor.dart';
import 'extractors/text_extractor.dart';
import 'extractors/xlsx_extractor.dart';
import 'file_scanner.dart';

/// map ชนิดไฟล์ → ตัว extract
final Map<FileKind, FileExtractor> kExtractors = {
  FileKind.pdf: PdfExtractor(),
  FileKind.xlsx: XlsxExtractor(),
  FileKind.docx: DocxExtractor(),
  FileKind.text: TextExtractor(),
};

/// ดึงข้อความของไฟล์ 1 ไฟล์ · pure Dart (xlsx/docx/text) โยนเข้า Isolate แยกกัน UI กระตุก
/// ส่วน PDF ต้องรันบน main isolate เพราะ PDFium init ไว้ฝั่งนั้น
Future<ExtractResult> extractFile(ScannedFile file) async {
  final extractor = kExtractors[file.kind];
  if (extractor == null) {
    return const ExtractResult.failed(
      status: FileStatus.error,
      note: 'ยังไม่รองรับชนิดไฟล์นี้',
    );
  }
  if (file.size > kMaxFileSizeBytes) {
    return const ExtractResult.failed(
      status: FileStatus.tooLarge,
      note: 'ไฟล์ใหญ่เกิน 64 MB — ข้ามการ index',
    );
  }
  if (extractor.isolateSafe) {
    return Isolate.run(() => _extractInIsolate(file.kind, file.path));
  }
  return extractor.extract(file.path);
}

Future<ExtractResult> _extractInIsolate(FileKind kind, String path) {
  // สร้าง extractor ใหม่ใน isolate (ห้ามส่ง object ข้าม isolate)
  final extractor = switch (kind) {
    FileKind.xlsx => XlsxExtractor(),
    FileKind.docx => DocxExtractor(),
    FileKind.text => TextExtractor(),
    FileKind.pdf => throw StateError('PDF ต้อง extract บน main isolate'),
  };
  return extractor.extract(path);
}

/// สร้าง/อัปเดต index ของโปรเจค (reindex เฉพาะไฟล์ที่ mtime หรือ size เปลี่ยน)
class Indexer {
  Indexer({
    required this.indexRepo,
    required this.projectRepo,
    this.scanner = const FileScanner(),
  });

  final IndexRepository indexRepo;
  final ProjectRepository projectRepo;
  final FileScanner scanner;

  Stream<ScanProgress> indexProject({
    required int projectId,
    required List<String> roots,
    bool force = false,
  }) async* {
    final files = await scanner.scan(roots);
    yield ScanProgress(done: 0, total: files.length);

    final known = indexRepo.indexedFingerprints(projectId);
    indexRepo.removeMissing(projectId, files.map((f) => f.path).toSet());

    var done = 0;
    for (final file in files) {
      final fingerprint = known[file.path];
      final unchanged = !force &&
          fingerprint != null &&
          fingerprint.mtimeMs == file.mtimeMs &&
          fingerprint.size == file.size;
      if (!unchanged) {
        final result = await extractFile(file);
        indexRepo.replaceFile(
          projectId: projectId,
          path: file.path,
          kind: file.kind,
          mtimeMs: file.mtimeMs,
          size: file.size,
          result: result,
        );
      }
      done++;
      yield ScanProgress(done: done, total: files.length, currentFile: file.path);
    }

    projectRepo.touchIndexedAt(projectId);
    yield ScanProgress(done: done, total: files.length, finished: true);
  }
}
