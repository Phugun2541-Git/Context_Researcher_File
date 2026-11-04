import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// สถานะสิทธิ์ที่เก็บไว้ในเครื่อง — ไม่เก็บใน index.db เพราะเปิดแก้ด้วย DB Browser ได้
class LicenseRecord {
  const LicenseRecord({required this.raw, required this.activatedAt, required this.lastSeenUtc});

  factory LicenseRecord.fromJson(Map<String, dynamic> json) => LicenseRecord(
    raw: '${json['lic']}',
    activatedAt: DateTime.parse('${json['activatedAt']}').toUtc(),
    lastSeenUtc: DateTime.parse('${json['lastSeen']}').toUtc(),
  );

  final String raw;
  final DateTime activatedAt;

  /// เวลาที่เห็นล่าสุด — ใช้จับการหมุนนาฬิกาถอยหลัง
  final DateTime lastSeenUtc;

  LicenseRecord copyWith({DateTime? lastSeenUtc}) => LicenseRecord(
    raw: raw,
    activatedAt: activatedAt,
    lastSeenUtc: lastSeenUtc ?? this.lastSeenUtc,
  );

  Map<String, dynamic> toJson() => {
    'lic': raw,
    'activatedAt': activatedAt.toUtc().toIso8601String(),
    'lastSeen': lastSeenUtc.toUtc().toIso8601String(),
  };
}

abstract class LicenseStore {
  /// null = ยังไม่เคย activate หรือไฟล์อ่านไม่ออก (ถือว่ายังไม่ activate)
  LicenseRecord? read();

  void write(LicenseRecord record);

  void clear();
}

/// เก็บลงไฟล์ที่เข้ารหัสด้วย Windows DPAPI (ผูกกับ user account ของเครื่องนั้น)
/// ⇒ copy ไฟล์ไปเครื่องอื่นหรือ user อื่นถอดไม่ออก
class DpapiLicenseStore implements LicenseStore {
  DpapiLicenseStore(this.filePath);

  /// entropy เพิ่มเติม ทำให้ถอดด้วย DPAPI เฉย ๆ จากโปรแกรมอื่นไม่ได้ ต้องรู้ค่านี้ด้วย
  static const _entropy = 'context-researcher-file/license/v1';

  final String filePath;

  @override
  LicenseRecord? read() {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;
      final plain = _unprotect(file.readAsBytesSync());
      if (plain == null) return null;
      final json = jsonDecode(utf8.decode(plain));
      if (json is! Map<String, dynamic>) return null;
      return LicenseRecord.fromJson(json);
    } catch (_) {
      // ไฟล์เสีย/ถอดไม่ออก = ถือว่ายังไม่ activate (ไม่ใช่โกง) ให้ผู้ใช้เลือกไฟล์ .lic ใหม่ได้
      return null;
    }
  }

  @override
  void write(LicenseRecord record) {
    final file = File(filePath);
    file.parent.createSync(recursive: true);
    final plain = Uint8List.fromList(utf8.encode(jsonEncode(record.toJson())));
    file.writeAsBytesSync(_protect(plain), flush: true);
  }

  @override
  void clear() {
    final file = File(filePath);
    if (file.existsSync()) file.deleteSync();
  }

  Uint8List _protect(Uint8List data) {
    final inBlob = calloc<CRYPT_INTEGER_BLOB>();
    final entropyBlob = calloc<CRYPT_INTEGER_BLOB>();
    final outBlob = calloc<CRYPT_INTEGER_BLOB>();
    final inBuf = calloc<Uint8>(data.length);
    final entropyBytes = utf8.encode(_entropy);
    final entropyBuf = calloc<Uint8>(entropyBytes.length);
    try {
      inBuf.asTypedList(data.length).setAll(0, data);
      inBlob.ref
        ..cbData = data.length
        ..pbData = inBuf;
      entropyBuf.asTypedList(entropyBytes.length).setAll(0, entropyBytes);
      entropyBlob.ref
        ..cbData = entropyBytes.length
        ..pbData = entropyBuf;
      final ok = CryptProtectData(
        inBlob,
        nullptr,
        entropyBlob,
        nullptr,
        nullptr,
        0,
        outBlob,
      );
      if (ok == 0) throw const FileSystemException('เข้ารหัสไฟล์สิทธิ์ไม่สำเร็จ');
      return Uint8List.fromList(outBlob.ref.pbData.asTypedList(outBlob.ref.cbData));
    } finally {
      if (outBlob.ref.pbData != nullptr) LocalFree(outBlob.ref.pbData);
      calloc
        ..free(inBuf)
        ..free(entropyBuf)
        ..free(inBlob)
        ..free(entropyBlob)
        ..free(outBlob);
    }
  }

  Uint8List? _unprotect(Uint8List blob) {
    final inBlob = calloc<CRYPT_INTEGER_BLOB>();
    final entropyBlob = calloc<CRYPT_INTEGER_BLOB>();
    final outBlob = calloc<CRYPT_INTEGER_BLOB>();
    final inBuf = calloc<Uint8>(blob.length);
    final entropyBytes = utf8.encode(_entropy);
    final entropyBuf = calloc<Uint8>(entropyBytes.length);
    try {
      inBuf.asTypedList(blob.length).setAll(0, blob);
      inBlob.ref
        ..cbData = blob.length
        ..pbData = inBuf;
      entropyBuf.asTypedList(entropyBytes.length).setAll(0, entropyBytes);
      entropyBlob.ref
        ..cbData = entropyBytes.length
        ..pbData = entropyBuf;
      final ok = CryptUnprotectData(
        inBlob,
        nullptr,
        entropyBlob,
        nullptr,
        nullptr,
        0,
        outBlob,
      );
      if (ok == 0) return null;
      return Uint8List.fromList(outBlob.ref.pbData.asTypedList(outBlob.ref.cbData));
    } finally {
      if (outBlob.ref.pbData != nullptr) LocalFree(outBlob.ref.pbData);
      calloc
        ..free(inBuf)
        ..free(entropyBuf)
        ..free(inBlob)
        ..free(entropyBlob)
        ..free(outBlob);
    }
  }
}

/// เก็บในหน่วยความจำ — ใช้ในเทสเท่านั้น (DPAPI เรียกได้เฉพาะบน Windows)
class MemoryLicenseStore implements LicenseStore {
  LicenseRecord? _record;

  @override
  void clear() => _record = null;

  @override
  LicenseRecord? read() => _record;

  @override
  void write(LicenseRecord record) => _record = record;
}
