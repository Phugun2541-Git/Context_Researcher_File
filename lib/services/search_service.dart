import 'dart:async';

import '../data/index_repository.dart';
import '../domain/models.dart';
import 'file_scanner.dart';
import 'indexer.dart';
import 'match_util.dart';

/// เหตุการณ์ของการค้นแบบ scan สด (ไม่ผูกโปรเจค) — ทยอยส่งผลทีละไฟล์
class LiveSearchEvent {
  const LiveSearchEvent({required this.progress, required this.results});

  final ScanProgress progress;
  final List<FileResult> results;
}

class SearchService {
  SearchService({required this.indexRepo, this.scanner = const FileScanner()});

  final IndexRepository indexRepo;
  final FileScanner scanner;

  /// โหมดโปรเจค: ค้นจาก index (เร็วระดับ ms)
  List<FileResult> searchIndexed({
    required int projectId,
    required String query,
    int hitsPerFile = 50,
  }) =>
      indexRepo.search(
        projectId: projectId,
        query: query,
        hitsPerFile: hitsPerFile,
      );

  /// โหมดค้นแบบไม่ผูกโปรเจค: อ่านไฟล์สด ไม่เขียนลง DB
  Stream<LiveSearchEvent> searchLive({
    required List<String> roots,
    required String query,
    int hitsPerFile = 50,
  }) async* {
    final q = query.trim();
    if (q.isEmpty || roots.isEmpty) return;

    final files = await scanner.scan(roots);
    final results = <FileResult>[];
    yield LiveSearchEvent(
      progress: ScanProgress(done: 0, total: files.length),
      results: const [],
    );

    var done = 0;
    for (final file in files) {
      final extracted = await extractFile(
        file,
        maxFileSizeBytes: scanner.maxFileSizeBytes,
      );
      final result = matchInChunks(
        path: file.path,
        kind: file.kind,
        mtimeMs: file.mtimeMs,
        extracted: extracted,
        query: q,
        hitsPerFile: hitsPerFile,
      );
      if (result != null) {
        results.add(result);
        results.sort((a, b) {
          final byHits = b.totalHits.compareTo(a.totalHits);
          return byHits != 0 ? byHits : a.fileName.compareTo(b.fileName);
        });
      }
      done++;
      yield LiveSearchEvent(
        progress: ScanProgress(
          done: done,
          total: files.length,
          currentFile: file.path,
          finished: done == files.length,
        ),
        results: List.unmodifiable(results),
      );
    }
  }
}

/// หาคำในผล extract ของไฟล์เดียว — คืน null ถ้าไม่พบและไม่มีอะไรต้องเตือน
FileResult? matchInChunks({
  required String path,
  required FileKind kind,
  required ExtractResult extracted,
  required String query,
  int hitsPerFile = 50,
  int mtimeMs = 0,
}) {
  if (extracted.status != FileStatus.ok) {
    // ไฟล์สแกน/อ่านไม่ได้ → ยังแสดงเป็นแถวเตือน เพื่อไม่ให้ผู้ใช้เข้าใจว่า "ไม่มีคำนี้"
    return FileResult(
      path: path,
      kind: kind,
      hits: const [],
      totalHits: 0,
      status: extracted.status,
      note: extracted.note,
      mtimeMs: mtimeMs,
    );
  }

  final hits = <SearchHit>[];
  var total = 0;
  for (final chunk in extracted.chunks) {
    final occurrences = findOccurrences(chunk.text, query);
    if (occurrences.isEmpty) continue;
    total += occurrences.length;
    if (hits.length < hitsPerFile) {
      hits.add(buildHit(
        locator: chunk.locator,
        text: chunk.text,
        matchIndex: occurrences.first,
        matchLength: query.length,
      ));
    }
  }
  if (total == 0) return null;
  return FileResult(
    path: path,
    kind: kind,
    hits: hits,
    totalHits: total,
    note: extracted.note,
    mtimeMs: mtimeMs,
  );
}
