import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:xml/xml_events.dart';

import '../../domain/models.dart';
import 'extractor.dart';

/// ดึงข้อความจาก .xlsx/.xlsm — chunk = 1 cell เพื่อชี้ตำแหน่งได้ระดับ `Sheet1!B12`
///
/// อ่าน OOXML เองด้วย xml event stream (ไม่ใช้ package `excel`) เพราะ:
/// 1) package `excel` crash กับไฟล์ที่ rels ชี้ path แบบ absolute (`/xl/worksheets/sheet1.xml`)
///    ซึ่งเป็นรูปแบบที่ตัว export หลายตัว (openpyxl ฯลฯ) เขียนออกมา
/// 2) stream ทีละ event ไม่ต้องสร้าง object model ของทั้ง workbook → กิน RAM น้อยกว่า
/// ข้อจำกัด: ค่าวันที่เก็บเป็น serial number ของ Excel จึงค้นเจอเป็นตัวเลขดิบ (ไม่แปลง format)
class XlsxExtractor implements FileExtractor {
  @override
  FileKind get kind => FileKind.xlsx;

  @override
  bool get isolateSafe => true;

  @override
  Future<ExtractResult> extract(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final workbook = XlsxWorkbook.fromArchive(archive);
      final chunks = <Chunk>[];
      var truncated = false;

      for (final sheet in workbook.sheets) {
        final xml = workbook.readText(sheet.target);
        if (xml == null) continue;
        for (final cell in parseSheetCells(xml, workbook.sharedStrings)) {
          if (chunks.length >= kMaxChunksPerFile) {
            truncated = true;
            break;
          }
          chunks.add(Chunk(
            locator: Locator(
              sheet: sheet.name,
              cell: cell.ref,
              row: cell.row,
            ),
            text: cell.text,
          ));
        }
        if (truncated) break;
      }

      return ExtractResult(
        chunks: chunks,
        note: truncated
            ? 'ไฟล์ใหญ่มาก index เฉพาะ $kMaxChunksPerFile ช่องแรก'
            : null,
      );
    } catch (e) {
      return ExtractResult.failed(
        status: FileStatus.error,
        note: 'อ่าน Excel ไม่ได้: $e',
      );
    }
  }
}

class XlsxSheetRef {
  const XlsxSheetRef({required this.name, required this.target});

  final String name;

  /// path ภายใน zip เช่น `xl/worksheets/sheet1.xml`
  final String target;
}

/// โครงของ workbook: ชื่อ sheet + ตำแหน่งไฟล์ + sharedStrings
class XlsxWorkbook {
  XlsxWorkbook({
    required this.archive,
    required this.sheets,
    required this.sharedStrings,
  });

  final Archive archive;
  final List<XlsxSheetRef> sheets;
  final List<String> sharedStrings;

  String? readText(String path) {
    final file = archive.findFile(path);
    if (file == null) return null;
    return utf8.decode(file.content as List<int>, allowMalformed: true);
  }

  static XlsxWorkbook fromArchive(Archive archive) {
    String? read(String path) {
      final file = archive.findFile(path);
      return file == null
          ? null
          : utf8.decode(file.content as List<int>, allowMalformed: true);
    }

    // rels: rId -> target (normalize path ให้เป็น path ใน zip เสมอ)
    final rels = <String, String>{};
    final relsXml = read('xl/_rels/workbook.xml.rels');
    if (relsXml != null) {
      for (final event in parseEvents(relsXml).whereType<XmlStartElementEvent>()) {
        if (event.name != 'Relationship') continue;
        final id = event.attributes
            .where((a) => a.name == 'Id')
            .map((a) => a.value)
            .firstOrNull;
        final target = event.attributes
            .where((a) => a.name == 'Target')
            .map((a) => a.value)
            .firstOrNull;
        if (id != null && target != null) rels[id] = normalizeTarget(target);
      }
    }

    // ลำดับ sheet + ชื่อ (ชื่อที่โชว์ใน chip ต้องเป็นชื่อ sheet จริง)
    final sheets = <XlsxSheetRef>[];
    final workbookXml = read('xl/workbook.xml');
    if (workbookXml != null) {
      var fallbackIndex = 0;
      for (final event
          in parseEvents(workbookXml).whereType<XmlStartElementEvent>()) {
        if (event.name != 'sheet') continue;
        fallbackIndex++;
        final name = event.attributes
                .where((a) => a.name == 'name')
                .map((a) => a.value)
                .firstOrNull ??
            'Sheet$fallbackIndex';
        final rid = event.attributes
            .where((a) => a.name == 'r:id' || a.name.endsWith(':id'))
            .map((a) => a.value)
            .firstOrNull;
        final target =
            rels[rid] ?? 'xl/worksheets/sheet$fallbackIndex.xml';
        sheets.add(XlsxSheetRef(name: name, target: target));
      }
    }

    // sharedStrings: index -> ข้อความ
    final shared = <String>[];
    final sharedXml =
        read('xl/sharedStrings.xml') ?? read('xl/SharedStrings.xml');
    if (sharedXml != null) {
      final buffer = StringBuffer();
      var inItem = false;
      var inText = false;
      for (final event in parseEvents(sharedXml)) {
        if (event is XmlStartElementEvent) {
          if (event.name == 'si') {
            inItem = true;
            buffer.clear();
          } else if (event.name == 't' && inItem) {
            inText = !event.isSelfClosing;
          }
        } else if (event is XmlTextEvent && inText) {
          buffer.write(event.value);
        } else if (event is XmlCDATAEvent && inText) {
          buffer.write(event.value);
        } else if (event is XmlEndElementEvent) {
          if (event.name == 't') {
            inText = false;
          } else if (event.name == 'si') {
            shared.add(buffer.toString());
            inItem = false;
          }
        }
      }
    }

    return XlsxWorkbook(
      archive: archive,
      sheets: sheets,
      sharedStrings: shared,
    );
  }
}

/// Target ใน rels อาจเป็น `/xl/worksheets/sheet1.xml`, `worksheets/sheet1.xml`
/// หรือ `../worksheets/sheet1.xml` → ทำให้เป็น path ใน zip รูปแบบเดียว
String normalizeTarget(String target) {
  var t = target.replaceAll('\\', '/');
  if (t.startsWith('/')) t = t.substring(1);
  while (t.startsWith('../')) {
    t = t.substring(3);
  }
  if (!t.startsWith('xl/')) t = 'xl/$t';
  return t;
}

class XlsxCell {
  const XlsxCell({required this.ref, required this.row, required this.text});

  /// cell ref แบบ Excel เช่น B12
  final String ref;
  final int row;
  final String text;
}

/// อ่าน cell ที่มีค่าออกจาก sheet xml (ข้ามช่องว่าง)
///
/// รองรับ: `t="s"` (sharedStrings) · `t="inlineStr"` · `t="str"` (ผลสูตร) · ตัวเลข/บูลีน
List<XlsxCell> parseSheetCells(String sheetXml, List<String> sharedStrings) {
  final out = <XlsxCell>[];

  String? currentRef;
  String? currentType;
  var rowNumber = 0;
  var columnIndex = 0;
  var inValue = false;
  var inInlineText = false;
  final buffer = StringBuffer();

  void flushCell() {
    final text = buffer.toString();
    buffer.clear();
    if (text.isEmpty) return;
    final ref = currentRef ?? '${columnLetter(columnIndex)}$rowNumber';
    final resolved = currentType == 's'
        ? (int.tryParse(text.trim()) != null &&
                int.parse(text.trim()) < sharedStrings.length
            ? sharedStrings[int.parse(text.trim())]
            : '')
        : text;
    if (resolved.trim().isEmpty) return;
    out.add(XlsxCell(
      ref: ref,
      row: rowNumber == 0 ? rowOfRef(ref) : rowNumber,
      text: resolved,
    ));
  }

  for (final event in parseEvents(sheetXml)) {
    if (event is XmlStartElementEvent) {
      switch (event.name) {
        case 'row':
          rowNumber = int.tryParse(event.attributes
                      .where((a) => a.name == 'r')
                      .map((a) => a.value)
                      .firstOrNull ??
                  '') ??
              rowNumber + 1;
          columnIndex = 0;
        case 'c':
          currentRef = event.attributes
              .where((a) => a.name == 'r')
              .map((a) => a.value)
              .firstOrNull;
          currentType = event.attributes
              .where((a) => a.name == 't')
              .map((a) => a.value)
              .firstOrNull;
          buffer.clear();
          if (event.isSelfClosing) {
            currentRef = null;
            columnIndex++;
          }
        case 'v':
          inValue = !event.isSelfClosing;
        case 't':
          // <is><t>..</t></is> ของ inlineStr
          inInlineText = !event.isSelfClosing && currentType == 'inlineStr';
        case 'f':
          // สูตร: เก็บแต่ค่าที่คำนวณไว้ (<v>) ไม่เก็บตัวสูตร
          break;
      }
    } else if (event is XmlTextEvent) {
      if (inValue || inInlineText) buffer.write(event.value);
    } else if (event is XmlCDATAEvent) {
      if (inValue || inInlineText) buffer.write(event.value);
    } else if (event is XmlEndElementEvent) {
      switch (event.name) {
        case 'v':
          inValue = false;
        case 't':
          inInlineText = false;
        case 'c':
          flushCell();
          currentRef = null;
          currentType = null;
          columnIndex++;
      }
    }
  }

  return out;
}

/// ดึงเลขแถวออกจาก cell ref (B12 -> 12)
int rowOfRef(String ref) =>
    int.tryParse(RegExp(r'\d+').firstMatch(ref)?.group(0) ?? '') ?? 0;

/// index คอลัมน์ (0-based) → ตัวอักษรแบบ Excel (0→A, 26→AA)
String columnLetter(int index) {
  var i = index;
  final buffer = <int>[];
  do {
    buffer.insert(0, 65 + (i % 26));
    i = i ~/ 26 - 1;
  } while (i >= 0);
  return String.fromCharCodes(buffer);
}
