// ออกใบอนุญาตให้ลูกค้า 1 เครื่อง
//
//   dart run tool/licgen.dart --machine <Machine ID> --days 30 --name "ชื่อลูกค้า"
//   dart run tool/licgen.dart --machine <Machine ID> --days 0          // ใช้ได้ตลอดไป
//   dart run tool/licgen.dart --machine <Machine ID> --until 2026-12-31 // ระบุวันหมดอายุตรง ๆ
//   dart run tool/licgen.dart --days 0 --name dev                      // ไม่ใส่ --machine = เครื่องที่รัน
//
// Machine ID เอามาจากหน้า activate ของเครื่องลูกค้า (กดคัดลอกแล้วส่งมา)
// ไฟล์ที่ได้ = <ชื่อ>.lic ส่งให้ลูกค้าเลือกในแอป · ต่ออายุ = ออกใบใหม่แล้วให้เลือกทับ

import 'dart:convert';
import 'dart:io';

import 'package:context_researcher_file/services/license/license_payload.dart';
import 'package:context_researcher_file/services/license/machine_id.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final opts = _parseArgs(args);

  // ไม่ใส่ --machine = ออกใบให้เครื่องที่รันคำสั่งนี้ (ใช้ตอนทำเครื่อง dev ของตัวเอง)
  final String machine;
  if ((opts['machine'] ?? '').isEmpty) {
    try {
      machine = MachineId.current();
    } catch (e) {
      stderr.writeln('อ่านรหัสเครื่องนี้ไม่ได้ ($e) — ระบุ --machine <Machine ID> เอง');
      exit(1);
    }
    stdout.writeln('ไม่ได้ระบุ --machine → ใช้รหัสของเครื่องนี้: ${MachineId.format(machine)}');
  } else {
    machine = _normalize(opts['machine']!);
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(machine)) {
      stderr.writeln('Machine ID ต้องเป็นค่าที่หน้า activate ของเครื่องลูกค้าแสดง (32 ตัว)');
      stderr.writeln('ตัวอย่าง: --machine A1B2-C3D4-E5F6-7890-A1B2-C3D4-E5F6-7890');
      exit(1);
    }
  }

  final issuedAt = DateTime.now().toUtc();

  // --until รับเป็นวันที่หมดอายุตรง ๆ แล้วแปลงเป็นจำนวนวันให้ (สะดวกกว่านับเอง)
  final int days;
  final until = opts['until'];
  if (until != null && until.isNotEmpty) {
    final target = DateTime.tryParse(until);
    if (target == null) {
      stderr.writeln('--until ต้องเป็นวันที่แบบ 2026-12-31');
      exit(1);
    }
    days = target.toUtc().difference(issuedAt).inHours ~/ 24 + 1;
    if (days <= 0) {
      stderr.writeln('--until เป็นวันที่ผ่านมาแล้ว');
      exit(1);
    }
  } else {
    final parsed = int.tryParse(opts['days'] ?? '0');
    if (parsed == null || parsed < 0) {
      stderr.writeln('--days ต้องเป็นจำนวนวัน (0 = ไม่มีวันหมดอายุ)');
      exit(1);
    }
    days = parsed;
  }

  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path;
  final privateFile = File(opts['key'] ?? p.join(home, '.crf-keys', 'ed25519_private.key'));
  if (!privateFile.existsSync()) {
    stderr.writeln('ไม่พบ private key ที่ ${privateFile.path} — รัน tool/keygen.dart ก่อน');
    exit(1);
  }

  final privateKey = ed.PrivateKey(base64.decode(privateFile.readAsStringSync().trim()));
  final payload = LicensePayload(
    version: LicensePayload.currentVersion,
    licenseId: '${issuedAt.millisecondsSinceEpoch.toRadixString(36)}'
        '-${machine.substring(0, 6)}',
    machineId: machine,
    days: days,
    issuedAt: issuedAt,
    name: opts['name'] ?? '',
  );

  final bytes = payload.toCanonicalBytes();
  final signature = ed.sign(privateKey, bytes);
  final outFile = File(opts['out'] ?? '${_safeName(opts['name'] ?? 'license')}.lic').absolute;
  outFile.parent.createSync(recursive: true);
  outFile.writeAsStringSync(LicenseFile.encode(bytes, signature));

  final expires = payload.expiresAt?.toLocal();
  stdout.writeln('');
  stdout.writeln('✔ ออกใบอนุญาตสำเร็จ');
  stdout.writeln('  ชื่อไฟล์ : ${p.basename(outFile.path)}');
  stdout.writeln('  ที่อยู่  : ${outFile.path}');
  stdout.writeln('  ขนาด    : ${outFile.lengthSync()} bytes');
  stdout.writeln('  ออกให้  : ${payload.name.isEmpty ? '(ไม่ได้ระบุชื่อ)' : payload.name}');
  stdout.writeln('  เครื่อง  : ${MachineId.format(machine)}');
  stdout.writeln(
    '  อายุ    : ${payload.perpetual ? 'ไม่มีวันหมดอายุ' : '$days วัน · หมดอายุ ${_thaiDate(expires!)}'}',
  );
  stdout.writeln('');
  stdout.writeln('ส่งไฟล์นี้ให้ลูกค้า แล้วให้กด "เลือกไฟล์ใบอนุญาต (.lic)" ในโปรแกรม');
}

String _thaiDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} น.';

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
