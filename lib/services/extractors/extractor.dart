import '../../domain/models.dart';

/// ตัวดึงข้อความออกจากไฟล์ 1 ชนิด
abstract class FileExtractor {
  FileKind get kind;

  /// ทำงานใน Isolate แยกได้ไหม (pure Dart = ได้ · ตัวที่พึ่ง plugin/FFI ที่ init บน main = ไม่ได้)
  bool get isolateSafe => true;

  Future<ExtractResult> extract(String path);
}

/// จำนวน chunk สูงสุดต่อไฟล์ — กันไฟล์ผิดปกติกิน RAM/DB
const kMaxChunksPerFile = 200000;

/// ตัดข้อความก้อนใหญ่เป็นบรรทัด + ทิ้งบรรทัดว่าง
List<String> splitNonEmptyLines(String text) {
  return text
      .split(RegExp(r'\r\n|\r|\n'))
      .map((l) => l.trimRight())
      .where((l) => l.trim().isNotEmpty)
      .toList();
}
