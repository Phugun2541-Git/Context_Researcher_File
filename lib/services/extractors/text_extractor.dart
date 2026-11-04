import 'dart:convert';
import 'dart:io';

import '../../domain/models.dart';
import 'extractor.dart';

/// txt / csv / tsv / md / log — chunk = 1 บรรทัด (locator = เลขบรรทัดจริง รวมบรรทัดว่าง)
class TextExtractor implements FileExtractor {
  @override
  FileKind get kind => FileKind.text;

  @override
  bool get isolateSafe => true;

  @override
  Future<ExtractResult> extract(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final content = decodeTextBytes(bytes);
      final lines = content.split(RegExp(r'\r\n|\r|\n'));
      final chunks = <Chunk>[];
      for (var i = 0; i < lines.length && chunks.length < kMaxChunksPerFile; i++) {
        if (lines[i].trim().isEmpty) continue;
        chunks.add(Chunk(locator: Locator(line: i + 1), text: lines[i]));
      }
      return ExtractResult(chunks: chunks);
    } catch (e) {
      return ExtractResult.failed(
        status: FileStatus.error,
        note: 'อ่านไฟล์ข้อความไม่ได้: $e',
      );
    }
  }
}

/// ลอง utf8 ก่อน · ถ้าเจอตัวแทนที่ (�) เยอะ = ไม่ใช่ utf8 → ถอยไป latin1
/// (ไฟล์ไทยเก่ารหัส TIS-620/CP874 จะอ่านได้แต่ตัวอักษรไม่ตรง — แจ้งไว้ใน docs)
String decodeTextBytes(List<int> bytes) {
  final asUtf8 = utf8.decode(bytes, allowMalformed: true);
  final bad = asUtf8.runes.where((r) => r == 0xFFFD).length;
  if (bad > asUtf8.length * 0.02) {
    return latin1.decode(bytes, allowInvalid: true);
  }
  return asUtf8;
}
