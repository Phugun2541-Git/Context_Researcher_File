import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// อ่านไม่ได้ = ไม่รู้ว่าเครื่องไหน — ต้องแยกจาก "ใบอนุญาตผิดเครื่อง" เพราะไม่ใช่ความผิดผู้ใช้
class MachineIdException implements Exception {
  const MachineIdException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// รหัสประจำเครื่อง = sha256(MachineGuid + volume serial ของไดรฟ์ระบบ)
///
/// MachineGuid อยู่ใน registry ตั้งแต่ตอนติดตั้ง Windows · volume serial เปลี่ยนเมื่อฟอร์แมตไดรฟ์
/// ใช้คู่กันเพื่อให้ copy โฟลเดอร์แอปไปเครื่องอื่นแล้วใช้ใบอนุญาตเดิมไม่ได้
class MachineId {
  const MachineId._();

  /// cache ไว้เพราะอ่าน registry ทุกครั้งที่เช็คสิทธิ์ไม่จำเป็น
  static String? _cached;

  /// โยน [MachineIdException] เมื่ออ่านค่าจากเครื่องไม่ได้
  static String current() {
    final cached = _cached;
    if (cached != null) return cached;
    if (!Platform.isWindows) {
      throw const MachineIdException('ระบบนี้รองรับเฉพาะ Windows');
    }
    final guid = _readMachineGuid();
    final serial = _readSystemVolumeSerial();
    final digest = sha256.convert(utf8.encode('crf1|$guid|$serial'));
    // ตัดเหลือ 32 ตัว (128 bit) พอต่อการแยกเครื่อง และสั้นพอให้ลูกค้าพิมพ์ส่งมาได้
    return _cached = digest.toString().substring(0, 32);
  }

  /// แบ่งเป็นกลุ่มละ 4 ตัว 8 กลุ่ม ให้ลูกค้าอ่าน/พิมพ์ส่งมาได้โดยไม่ตกหล่น
  static String format(String id) {
    final short = id.length > 32 ? id.substring(0, 32) : id;
    // (ค่าที่เก็บในใบอนุญาตคือตัวพิมพ์เล็กไม่มีขีด — ขีดมีไว้ให้คนอ่านเท่านั้น)
    final groups = <String>[];
    for (var i = 0; i < short.length; i += 4) {
      groups.add(short.substring(i, i + 4 > short.length ? short.length : i + 4));
    }
    return groups.join('-').toUpperCase();
  }

  static String _readMachineGuid() {
    final subKey = r'SOFTWARE\Microsoft\Cryptography'.toNativeUtf16();
    final valueName = 'MachineGuid'.toNativeUtf16();
    final size = calloc<Uint32>();
    Pointer<Uint16>? buffer;
    try {
      // เรียกรอบแรกเพื่อถามขนาดที่ต้องใช้ (pvData = nullptr)
      var status = RegGetValue(
        HKEY_LOCAL_MACHINE,
        subKey,
        valueName,
        RRF_RT_REG_SZ,
        nullptr,
        nullptr,
        size,
      );
      if (status != ERROR_SUCCESS || size.value == 0) {
        throw const MachineIdException('อ่าน MachineGuid ของเครื่องไม่ได้');
      }
      buffer = calloc<Uint16>(size.value ~/ 2 + 1);
      status = RegGetValue(
        HKEY_LOCAL_MACHINE,
        subKey,
        valueName,
        RRF_RT_REG_SZ,
        nullptr,
        buffer,
        size,
      );
      if (status != ERROR_SUCCESS) {
        throw const MachineIdException('อ่าน MachineGuid ของเครื่องไม่ได้');
      }
      final value = buffer.cast<Utf16>().toDartString();
      if (value.trim().isEmpty) {
        throw const MachineIdException('อ่าน MachineGuid ของเครื่องไม่ได้');
      }
      return value.trim();
    } finally {
      calloc
        ..free(subKey)
        ..free(valueName)
        ..free(size);
      if (buffer != null) calloc.free(buffer);
    }
  }

  static String _readSystemVolumeSerial() {
    // ไดรฟ์ที่ Windows ติดตั้งอยู่ (ปกติ C:\) — ใช้ค่าจากระบบ ไม่ fix ไว้
    final systemDrive = Platform.environment['SystemDrive'] ?? 'C:';
    final root = '$systemDrive\\'.toNativeUtf16();
    final serial = calloc<Uint32>();
    try {
      final ok = GetVolumeInformation(
        root,
        nullptr,
        0,
        serial,
        nullptr,
        nullptr,
        nullptr,
        0,
      );
      if (ok == 0) {
        throw const MachineIdException('อ่านหมายเลขไดรฟ์ระบบไม่ได้');
      }
      return serial.value.toRadixString(16);
    } finally {
      calloc
        ..free(root)
        ..free(serial);
    }
  }
}
