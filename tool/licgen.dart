// ออกใบอนุญาตให้ลูกค้า 1 เครื่อง
//
//   dart run tool/licgen.dart --machine <Machine ID> --days 30 --name "ชื่อลูกค้า"
//   dart run tool/licgen.dart --machine <Machine ID> --days 0        // ใช้ได้ตลอดไป
//
// Machine ID เอามาจากหน้า activate ของเครื่องลูกค้า (กดคัดลอกแล้วส่งมา)
// ไฟล์ที่ได้ = <ชื่อ>.lic ส่งให้ลูกค้าเลือกในแอป · ต่ออายุ = ออกใบใหม่แล้วให้เลือกทับ

import 'dart:convert';
import 'dart:io';

import 'package:context_researcher_file/services/license/license_payload.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final opts = _parseArgs(args);
  final machine = opts['machine'];
  if (machine == null || machine.isEmpty) {
    stderr.writeln('ต้องระบุ --machine <Machine ID ของเครื่องลูกค้า>');
    exit(1);
  }
  final days = int.tryParse(opts['days'] ?? '0');
  if (days == null || days < 0) {
    stderr.writeln('--days ต้องเป็นจำนวนวัน (0 = ไม่มีวันหมดอายุ)');
    exit(1);
  }

  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path;
  final privateFile = File(opts['key'] ?? p.join(home, '.crf-keys', 'ed25519_private.key'));
  if (!privateFile.existsSync()) {
    stderr.writeln('ไม่พบ private key ที่ ${privateFile.path} — รัน tool/keygen.dart ก่อน');
    exit(1);
  }

  final privateKey = ed.PrivateKey(base64.decode(privateFile.readAsStringSync().trim()));
  final issuedAt = DateTime.now().toUtc();
  final payload = LicensePayload(
    version: LicensePayload.currentVersion,
    licenseId: '${issuedAt.millisecondsSinceEpoch.toRadixString(36)}'
        '-${_normalize(machine).substring(0, 6)}',
    machineId: _normalize(machine),
    days: days,
    issuedAt: issuedAt,
    name: opts['name'] ?? '',
  );

  final bytes = payload.toCanonicalBytes();
  final signature = ed.sign(privateKey, bytes);
  final outPath = opts['out'] ?? '${_safeName(opts['name'] ?? 'license')}.lic';
  File(outPath).writeAsStringSync(LicenseFile.encode(bytes, signature));

  stdout.writeln('ออกใบอนุญาตแล้ว → $outPath');
  stdout.writeln('เครื่อง: ${payload.machineId}');
  stdout.writeln(
    'อายุ: ${payload.perpetual ? 'ไม่มีวันหมดอายุ' : '$days วัน (ถึง ${payload.expiresAt!.toIso8601String()})'}',
  );
}

/// รับได้ทั้งแบบมีขีดคั่นที่หน้าแอปแสดง และแบบ hash เต็ม
String _normalize(String machine) => machine.replaceAll('-', '').trim().toLowerCase();

String _safeName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[^\w\-ก-๙]+'), '_').trim();
  return cleaned.isEmpty ? 'license' : cleaned;
}

Map<String, String> _parseArgs(List<String> args) {
  final map = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (!a.startsWith('--')) continue;
    final key = a.substring(2);
    final value = i + 1 < args.length && !args[i + 1].startsWith('--') ? args[++i] : '';
    map[key] = value;
  }
  return map;
}
