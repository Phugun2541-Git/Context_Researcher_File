// สร้างคู่กุญแจ Ed25519 สำหรับออกใบอนุญาต — รันครั้งเดียวตอนตั้งระบบ
//
//   dart run tool/keygen.dart
//
// private key ถูกเขียนไว้นอก repo (%USERPROFILE%\.crf-keys\ed25519_private.key)
// ★ ห้ามนำ private key เข้า repo หรือส่งให้ใคร — ใครได้ไปจะออกใบอนุญาตเองได้ทั้งหมด
// public key ที่พิมพ์ออกมา ให้ก๊อปไปวางใน lib/services/license/license_public_key.dart

import 'dart:convert';
import 'dart:io';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final home =
      Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path;
  final dir = Directory(p.join(home, '.crf-keys'));
  final privateFile = File(p.join(dir.path, 'ed25519_private.key'));

  if (privateFile.existsSync() && !args.contains('--force')) {
    stderr.writeln('มีกุญแจอยู่แล้วที่ ${privateFile.path}');
    stderr.writeln('ถ้าสร้างใหม่ ใบอนุญาตที่เคยออกไปแล้วจะใช้ไม่ได้ทั้งหมด');
    stderr.writeln('ยืนยันด้วย: dart run tool/keygen.dart --force');
    exit(1);
  }

  final pair = ed.generateKey();
  dir.createSync(recursive: true);
  privateFile.writeAsStringSync(base64.encode(pair.privateKey.bytes));
  final publicB64 = base64.encode(pair.publicKey.bytes);

  stdout.writeln('private key → ${privateFile.path}  (เก็บเป็นความลับ สำรองไว้ด้วย)');
  stdout.writeln('');
  stdout.writeln('วางค่านี้ใน lib/services/license/license_public_key.dart:');
  stdout.writeln("const kLicensePublicKeyBase64 = '$publicB64';");
}
