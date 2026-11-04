import 'dart:convert';
import 'dart:typed_data';

import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;

import 'license_payload.dart';
import 'license_public_key.dart';

/// ตรวจลายเซ็น Ed25519 ของใบอนุญาตด้วย public key ที่ฝังมากับแอป
class LicenseVerifier {
  LicenseVerifier({String? publicKeyBase64})
    : _publicKeyBase64 = publicKeyBase64 ?? kLicensePublicKeyBase64;

  final String _publicKeyBase64;

  bool get configured => _publicKeyBase64.trim().isNotEmpty;

  /// true = ลายเซ็นตรงกับไบต์ของ payload ชุดนี้จริง
  bool verify(LicenseFile file) {
    if (!configured) return false;
    final Uint8List key;
    try {
      key = base64.decode(_publicKeyBase64.trim());
    } catch (_) {
      return false;
    }
    if (key.length != 32) return false;
    try {
      return ed.verify(ed.PublicKey(key), file.payloadBytes, file.signature);
    } catch (_) {
      // ลายเซ็นสั้น/ยาวผิดขนาดทำให้ package โยน exception — ถือเป็นตรวจไม่ผ่าน
      return false;
    }
  }
}
