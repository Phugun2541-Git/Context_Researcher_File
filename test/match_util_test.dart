import 'package:context_researcher_file/domain/models.dart';
import 'package:context_researcher_file/services/match_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('findOccurrences', () {
    test('หาคำไทยกลางประโยคได้ทุกตำแหน่ง', () {
      const text = 'ใบเคลม RMA ของลูกค้า RMA รายนี้';
      expect(findOccurrences(text, 'RMA').length, 2);
    });

    test('ไม่สนตัวพิมพ์เล็กใหญ่', () {
      expect(findOccurrences('มี rma และ RMA', 'Rma').length, 2);
    });

    test('คำว่างคืนลิสต์ว่าง', () {
      expect(findOccurrences('ข้อความ', ''), isEmpty);
    });

    test('ไม่นับซ้อนทับ (aaa หา aa = 1 ครั้ง)', () {
      expect(findOccurrences('aaa', 'aa').length, 1);
    });
  });

  group('buildHit', () {
    test('snippet ชี้ตำแหน่งคำถูกหลังตัดหัวท้าย', () {
      final text = '${'x' * 200}RMA${'y' * 200}';
      final hit = buildHit(
        locator: const Locator(line: 3),
        text: text,
        matchIndex: 200,
        matchLength: 3,
      );
      expect(
        hit.snippet.substring(hit.matchStart, hit.matchStart + hit.matchLength),
        'RMA',
      );
      expect(hit.snippet.startsWith('… '), isTrue);
      expect(hit.snippet.endsWith(' …'), isTrue);
    });

    test('ยุบ whitespace แล้วยังชี้คำถูก', () {
      const text = 'หัวเรื่อง\n\n   คำว่า RMA   อยู่ตรงนี้';
      final index = findOccurrences(text, 'RMA').first;
      final hit = buildHit(
        locator: const Locator(page: 1),
        text: text,
        matchIndex: index,
        matchLength: 3,
      );
      expect(
        hit.snippet.substring(hit.matchStart, hit.matchStart + hit.matchLength),
        'RMA',
      );
      expect(hit.snippet.contains('\n'), isFalse);
    });
  });

  group('เงื่อนไข FTS', () {
    test('คำสั้นกว่า 3 ตัวอักษรใช้ trigram ไม่ได้', () {
      expect(canUseFts('ab'), isFalse);
      expect(canUseFts('abc'), isTrue);
      expect(canUseFts('  ก '), isFalse);
    });

    test('escape เครื่องหมายคำพูดใน phrase', () {
      expect(toFtsPhrase('เขาบอกว่า "ok"'), '"เขาบอกว่า ""ok"""');
    });

    test('escape wildcard ของ LIKE', () {
      expect(toLikePattern('50%_off'), r'%50\%\_off%');
    });
  });

  group('Locator label', () {
    test('ป้าย chip ตามชนิดไฟล์', () {
      expect(const Locator(page: 4).label, 'หน้า 4');
      expect(const Locator(sheet: 'Sheet1', cell: 'B12', row: 12).label, 'Sheet1!B12');
      expect(const Locator(line: 88).label, 'บรรทัด 88');
      expect(const Locator(paragraph: 2).label, 'ย่อหน้า 2');
    });

    test('json ไป-กลับได้ค่าเดิม', () {
      const l = Locator(sheet: 'ใบเสนอราคา', cell: 'C3', row: 3);
      final back = Locator.fromJson(l.toJson());
      expect(back.label, l.label);
      expect(back.sheet, 'ใบเสนอราคา');
    });
  });
}
