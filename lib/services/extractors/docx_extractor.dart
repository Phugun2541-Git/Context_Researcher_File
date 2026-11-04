import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';

import '../../domain/models.dart';
import 'extractor.dart';

/// ดึงข้อความจาก .docx โดยแกะ zip เอา word/document.xml (+ header/footer) แล้วถอด tag
///
/// ไม่มี package Dart ที่อ่าน docx ได้ดี จึง parse เองแบบจำกัดขอบเขต:
/// 1 ย่อหน้า (`<w:p>`) = 1 chunk → locator = เลขย่อหน้า
class DocxExtractor implements FileExtractor {
  @override
  FileKind get kind => FileKind.docx;

  @override
  bool get isolateSafe => true;

  @override
  Future<ExtractResult> extract(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final targets = archive.files.where((f) =>
          f.isFile &&
          (f.name == 'word/document.xml' ||
              f.name.startsWith('word/header') ||
              f.name.startsWith('word/footer')));

      final chunks = <Chunk>[];
      var paragraphNo = 0;
      for (final file in targets) {
        final xml = utf8.decode(file.content as List<int>, allowMalformed: true);
        for (final text in docxParagraphs(xml)) {
          if (chunks.length >= kMaxChunksPerFile) break;
          paragraphNo++;
          chunks.add(Chunk(
            locator: Locator(paragraph: paragraphNo),
            text: text,
          ));
        }
      }
      if (chunks.isEmpty) {
        return const ExtractResult.failed(
          status: FileStatus.noText,
          note: 'ไม่พบข้อความใน Word (ไฟล์อาจมีแต่รูป)',
        );
      }
      return ExtractResult(chunks: chunks);
    } catch (e) {
      return ExtractResult.failed(
        status: FileStatus.error,
        note: 'อ่าน Word ไม่ได้: $e',
      );
    }
  }
}

final _paragraphSplit = RegExp(r'</w:p>');
final _runText = RegExp(r'<w:t(?:\s[^>]*)?>(.*?)</w:t>', dotAll: true);
final _tabOrBreak = RegExp(r'<w:(?:tab|br|cr)\s*/>');

/// แปลง XML ของ docx เป็นข้อความต่อย่อหน้า (ทิ้งย่อหน้าว่าง)
List<String> docxParagraphs(String xml) {
  final out = <String>[];
  for (final block in xml.split(_paragraphSplit)) {
    final withBreaks = block.replaceAll(_tabOrBreak, ' ');
    final buffer = StringBuffer();
    for (final m in _runText.allMatches(withBreaks)) {
      buffer.write(unescapeXml(m.group(1) ?? ''));
    }
    final text = buffer.toString().trim();
    if (text.isNotEmpty) out.add(text);
  }
  return out;
}

String unescapeXml(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');
