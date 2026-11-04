import 'dart:convert';
import 'dart:typed_data';

/// ข้อมูลในใบอนุญาต 1 ใบ · `days = 0` คือใช้ได้ตลอดไป (ไม่มีวันหมดอายุ)
class LicensePayload {
  const LicensePayload({
    required this.version,
    required this.licenseId,
    required this.machineId,
    required this.days,
    required this.issuedAt,
    required this.name,
  });

  factory LicensePayload.fromJson(Map<String, dynamic> json) {
    final issued = DateTime.tryParse('${json['iat']}');
    if (issued == null) throw const LicenseFormatException('วันที่ออกใบอนุญาตไม่ถูกต้อง');
    return LicensePayload(
      version: (json['v'] as num?)?.toInt() ?? 0,
      licenseId: '${json['lid']}',
      machineId: '${json['mid']}',
      days: (json['days'] as num?)?.toInt() ?? 0,
      issuedAt: issued.toUtc(),
      name: json['name'] == null ? '' : '${json['name']}',
    );
  }

  /// รุ่นของรูปแบบ payload — เผื่อเปลี่ยนโครงในอนาคตแล้วยังอ่านใบเก่าออก
  static const currentVersion = 1;

  final int version;
  final String licenseId;
  final String machineId;
  final int days;
  final DateTime issuedAt;
  final String name;

  bool get perpetual => days <= 0;

  DateTime? get expiresAt => perpetual ? null : issuedAt.add(Duration(days: days));

  /// ลำดับ key คงที่ เพราะไบต์ชุดนี้คือสิ่งที่ถูกเซ็น
  Map<String, dynamic> toJson() => {
    'v': version,
    'lid': licenseId,
    'mid': machineId,
    'days': days,
    'iat': issuedAt.toUtc().toIso8601String(),
    'name': name,
  };

  Uint8List toCanonicalBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));
}

/// ไฟล์ `.lic` ที่แกะแล้ว — เก็บไบต์ของ payload ไว้ตรง ๆ
/// เพื่อให้ตรวจลายเซ็นกับไบต์ชุดเดียวกับตอนเซ็น ไม่ใช่ json ที่ประกอบขึ้นใหม่
class LicenseFile {
  const LicenseFile({
    required this.payload,
    required this.payloadBytes,
    required this.signature,
    required this.raw,
  });

  /// แกะข้อความในไฟล์ `.lic`
  factory LicenseFile.parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text.trim());
    } catch (_) {
      throw const LicenseFormatException('ไฟล์นี้ไม่ใช่ไฟล์ใบอนุญาต');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const LicenseFormatException('ไฟล์นี้ไม่ใช่ไฟล์ใบอนุญาต');
    }
    final payloadB64 = decoded['payload'];
    final sigB64 = decoded['sig'];
    if (payloadB64 is! String || sigB64 is! String) {
      throw const LicenseFormatException('ไฟล์ใบอนุญาตไม่ครบส่วน');
    }
    final Uint8List payloadBytes;
    final Uint8List signature;
    try {
      payloadBytes = base64Url.decode(payloadB64);
      signature = base64Url.decode(sigB64);
    } catch (_) {
      throw const LicenseFormatException('ไฟล์ใบอนุญาตเสียหาย');
    }
    final Object? inner;
    try {
      inner = jsonDecode(utf8.decode(payloadBytes));
    } catch (_) {
      throw const LicenseFormatException('ไฟล์ใบอนุญาตเสียหาย');
    }
    if (inner is! Map<String, dynamic>) {
      throw const LicenseFormatException('ไฟล์ใบอนุญาตเสียหาย');
    }
    return LicenseFile(
      payload: LicensePayload.fromJson(inner),
      payloadBytes: payloadBytes,
      signature: signature,
      raw: text.trim(),
    );
  }

  /// ประกอบเนื้อไฟล์ `.lic` (ใช้ที่ tool/licgen.dart)
  static String encode(Uint8List payloadBytes, Uint8List signature) => const JsonEncoder.withIndent(
    '  ',
  ).convert({'payload': base64Url.encode(payloadBytes), 'sig': base64Url.encode(signature)});

  final LicensePayload payload;
  final Uint8List payloadBytes;
  final Uint8List signature;
  final String raw;
}

class LicenseFormatException implements Exception {
  const LicenseFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}
