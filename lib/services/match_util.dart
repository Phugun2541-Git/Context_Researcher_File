import '../domain/models.dart';

/// หาตำแหน่งทุกครั้งที่พบคำค้น (case-insensitive · ไทยไม่มี case จึงเทียบ lowercase ได้ตรง)
List<int> findOccurrences(String text, String query) {
  if (query.isEmpty) return const [];
  final haystack = text.toLowerCase();
  final needle = query.toLowerCase();
  final out = <int>[];
  var from = 0;
  while (true) {
    final i = haystack.indexOf(needle, from);
    if (i < 0) break;
    out.add(i);
    from = i + needle.length;
  }
  return out;
}

/// ตัดข้อความรอบ ๆ จุดที่พบ (± radius ตัวอักษร) + คืนตำแหน่งคำใน snippet เพื่อระบายสี
SearchHit buildHit({
  required Locator locator,
  required String text,
  required int matchIndex,
  required int matchLength,
  int radius = 60,
}) {
  var start = matchIndex - radius;
  var end = matchIndex + matchLength + radius;
  var prefix = '';
  var suffix = '';
  if (start > 0) {
    prefix = '… ';
  } else {
    start = 0;
  }
  if (end < text.length) {
    suffix = ' …';
  } else {
    end = text.length;
  }
  final raw = text.substring(start, end).replaceAll(RegExp(r'\s+'), ' ');
  // หลังยุบ whitespace ตำแหน่งอาจเลื่อน → หาคำในชิ้นที่ตัดมาอีกครั้ง
  final sliceQuery = text.substring(matchIndex, matchIndex + matchLength);
  final local = raw.toLowerCase().indexOf(sliceQuery.toLowerCase());
  return SearchHit(
    locator: locator,
    snippet: '$prefix$raw$suffix',
    matchStart: local < 0 ? 0 : local + prefix.length,
    matchLength: local < 0 ? 0 : matchLength,
  );
}

/// FTS5 trigram ต้องการคำค้นยาว >= 3 ตัวอักษร · สั้นกว่านั้น fallback เป็น LIKE
const kMinFtsQueryLength = 3;

bool canUseFts(String query) => query.trim().length >= kMinFtsQueryLength;

/// ห่อคำค้นเป็น phrase ของ FTS5 (escape double-quote)
String toFtsPhrase(String query) => '"${query.trim().replaceAll('"', '""')}"';

/// escape สำหรับ LIKE (ใช้ ESCAPE '\')
String toLikePattern(String query) {
  final escaped = query
      .trim()
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
  return '%$escaped%';
}
