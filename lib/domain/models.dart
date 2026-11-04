import 'dart:convert';

/// ชนิดไฟล์ที่ระบบรองรับ (รอบแรก: pdf / xlsx / docx / csv-txt)
enum FileKind {
  pdf,
  xlsx,
  docx,
  text;

  static const extensionMap = <String, FileKind>{
    '.pdf': FileKind.pdf,
    '.xlsx': FileKind.xlsx,
    '.xlsm': FileKind.xlsx,
    '.docx': FileKind.docx,
    '.txt': FileKind.text,
    '.csv': FileKind.text,
    '.tsv': FileKind.text,
    '.md': FileKind.text,
    '.log': FileKind.text,
  };

  static FileKind? fromExtension(String ext) =>
      extensionMap[ext.toLowerCase()];

  String get label => switch (this) {
        FileKind.pdf => 'PDF',
        FileKind.xlsx => 'Excel',
        FileKind.docx => 'Word',
        FileKind.text => 'Text',
      };
}

/// สถานะไฟล์หลัง index
enum FileStatus {
  ok,
  noText, // PDF สแกน: ไม่มี text layer → ค้นไม่เจอ (ไม่ OCR ตามที่เจ้าของเคาะ)
  tooLarge,
  error,
}

class Project {
  Project({
    required this.id,
    required this.name,
    required this.createdAt,
    this.roots = const [],
    this.fileCount = 0,
    this.lastIndexedAt,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final List<ProjectRoot> roots;
  final int fileCount;
  final DateTime? lastIndexedAt;
}

class ProjectRoot {
  const ProjectRoot({required this.id, required this.path, required this.isFile});

  final int id;
  final String path;
  final bool isFile;
}

/// ตำแหน่งที่พบคำ — รูปแบบต่างกันตามชนิดไฟล์ แต่เก็บเป็น json ก้อนเดียว
class Locator {
  const Locator({this.page, this.sheet, this.cell, this.row, this.line, this.paragraph});

  final int? page; // pdf (1-based)
  final String? sheet; // xlsx
  final String? cell; // xlsx เช่น B12
  final int? row; // xlsx (1-based)
  final int? line; // txt/csv (1-based)
  final int? paragraph; // docx (1-based)

  Map<String, dynamic> toMap() => {
        if (page != null) 'page': page,
        if (sheet != null) 'sheet': sheet,
        if (cell != null) 'cell': cell,
        if (row != null) 'row': row,
        if (line != null) 'line': line,
        if (paragraph != null) 'paragraph': paragraph,
      };

  String toJson() => jsonEncode(toMap());

  static Locator fromJson(String source) {
    final m = jsonDecode(source) as Map<String, dynamic>;
    return Locator(
      page: m['page'] as int?,
      sheet: m['sheet'] as String?,
      cell: m['cell'] as String?,
      row: m['row'] as int?,
      line: m['line'] as int?,
      paragraph: m['paragraph'] as int?,
    );
  }

  /// ข้อความบน chip เช่น "หน้า 4" / "Sheet1!B12" / "บรรทัด 88"
  String get label {
    if (page != null) return 'หน้า $page';
    if (sheet != null) return '$sheet!${cell ?? 'A$row'}';
    if (line != null) return 'บรรทัด $line';
    if (paragraph != null) return 'ย่อหน้า $paragraph';
    return '-';
  }
}

/// 1 chunk = 1 หน่วยข้อความที่ index (1 บรรทัด / 1 cell / 1 ย่อหน้า / 1 หน้า PDF)
class Chunk {
  const Chunk({required this.locator, required this.text});

  final Locator locator;
  final String text;
}

/// ผลการ extract ของไฟล์ 1 ไฟล์
class ExtractResult {
  const ExtractResult({
    required this.chunks,
    this.status = FileStatus.ok,
    this.note,
  });

  const ExtractResult.failed({required this.status, required this.note})
      : chunks = const [];

  final List<Chunk> chunks;
  final FileStatus status;
  final String? note;
}

/// 1 จุดที่พบคำในไฟล์
class SearchHit {
  const SearchHit({
    required this.locator,
    required this.snippet,
    required this.matchStart,
    required this.matchLength,
  });

  final Locator locator;
  final String snippet;
  final int matchStart; // ตำแหน่งคำใน snippet (ใช้ระบายสี highlight)
  final int matchLength;
}

/// ผลรวมต่อ 1 ไฟล์ (list ด้านขวาแสดงระดับนี้)
class FileResult {
  const FileResult({
    required this.path,
    required this.kind,
    required this.hits,
    required this.totalHits,
    this.status = FileStatus.ok,
    this.note,
  });

  final String path;
  final FileKind kind;
  final List<SearchHit> hits; // จำกัดจำนวนที่แสดง
  final int totalHits;
  final FileStatus status;
  final String? note;

  String get fileName => path.split(RegExp(r'[\\/]')).last;
}

/// ความคืบหน้าของการ index / scan
class ScanProgress {
  const ScanProgress({
    required this.done,
    required this.total,
    this.currentFile,
    this.finished = false,
  });

  final int done;
  final int total;
  final String? currentFile;
  final bool finished;

  double get ratio => total == 0 ? 0 : done / total;
}
