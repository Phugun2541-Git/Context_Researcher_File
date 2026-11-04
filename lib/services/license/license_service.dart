import 'dart:io';

import 'license_payload.dart';
import 'license_store.dart';
import 'license_verifier.dart';

enum LicenseStatus {
  /// ใช้งานได้
  active,

  /// ยังไม่เคยใส่ใบอนุญาต
  none,

  /// หมดอายุแล้ว
  expired,

  /// ใบอนุญาตของเครื่องอื่น
  machineMismatch,

  /// ลายเซ็นไม่ผ่าน / ไฟล์ถูกแก้
  invalid,

  /// เวลาเครื่องถูกหมุนถอยหลัง
  clockTampered,

  /// อ่านรหัสเครื่องไม่ได้ (ไม่ใช่ความผิดผู้ใช้)
  machineUnreadable,

  /// แอปยังไม่ได้ฝัง public key (เจ้าของยังไม่รัน keygen)
  notConfigured,
}

class LicenseState {
  const LicenseState({
    required this.status,
    this.payload,
    this.daysLeft,
    this.message,
    this.machineId,
  });

  final LicenseStatus status;
  final LicensePayload? payload;

  /// null = ไม่มีวันหมดอายุ
  final int? daysLeft;
  final String? message;
  final String? machineId;

  bool get allowed => status == LicenseStatus.active;

  bool get perpetual => payload?.perpetual ?? false;

  /// เหลือน้อยกว่าเกณฑ์เตือน (ใบไม่มีวันหมดอายุไม่เข้าเงื่อนไขนี้)
  bool get expiringSoon =>
      status == LicenseStatus.active && daysLeft != null && daysLeft! <= kLicenseWarnDays;
}

/// เตือนล่วงหน้ากี่วันก่อนหมดอายุ
const kLicenseWarnDays = 7;

/// ยอมให้นาฬิกาคลาดได้เท่านี้ก่อนถือว่าโดนหมุนถอยหลัง
const kClockSkewTolerance = Duration(hours: 1);

/// รวมทุกอย่างเป็นสถานะเดียวให้ UI ใช้: ตรวจลายเซ็น · ผูกเครื่อง · อายุ · นาฬิกา
class LicenseService {
  LicenseService({
    required this.store,
    required this.machineIdProvider,
    LicenseVerifier? verifier,
    DateTime Function()? clock,
  }) : verifier = verifier ?? LicenseVerifier(),
       _clock = clock ?? (() => DateTime.now().toUtc());

  final LicenseStore store;
  final LicenseVerifier verifier;

  /// แยกออกมาเป็น callback เพื่อให้เทสใส่รหัสเครื่องปลอมได้ (ของจริงอ่าน registry)
  final String Function() machineIdProvider;
  final DateTime Function() _clock;

  /// ตรวจสถานะปัจจุบัน + บันทึกเวลาที่เห็นล่าสุด
  LicenseState check() {
    if (!verifier.configured) {
      return const LicenseState(
        status: LicenseStatus.notConfigured,
        message: 'แอปนี้ยังไม่ได้ฝังกุญแจตรวจใบอนุญาต (ยังไม่ได้ตั้งค่าก่อนแจก)',
      );
    }

    final String machine;
    try {
      machine = machineIdProvider();
    } catch (e) {
      // อ่านรหัสเครื่องไม่ได้ ≠ โกง — บอกตรง ๆ ว่าอ่านไม่ได้ ไม่ใช่ว่าใบอนุญาตผิด
      return LicenseState(status: LicenseStatus.machineUnreadable, message: '$e');
    }

    final record = store.read();
    if (record == null) {
      return LicenseState(status: LicenseStatus.none, machineId: machine);
    }

    final LicenseFile file;
    try {
      file = LicenseFile.parse(record.raw);
    } on LicenseFormatException catch (e) {
      return LicenseState(
        status: LicenseStatus.invalid,
        machineId: machine,
        message: e.message,
      );
    }

    final state = _evaluate(file, machine, record.lastSeenUtc);
    if (state.status == LicenseStatus.active) {
      final now = _clock();
      if (now.isAfter(record.lastSeenUtc)) {
        store.write(record.copyWith(lastSeenUtc: now));
      }
    }
    return state;
  }

  /// ใส่ใบอนุญาตใหม่ (ใบต่ออายุก็ใช้ทางนี้ — เขียนทับใบเดิม)
  LicenseState activateFromFile(String path) {
    try {
      return activateFromText(File(path).readAsStringSync());
    } catch (e) {
      if (e is LicenseFormatException) rethrow;
      return LicenseState(status: LicenseStatus.invalid, message: 'เปิดไฟล์ไม่ได้: $e');
    }
  }

  LicenseState activateFromText(String text) {
    if (!verifier.configured) {
      return const LicenseState(
        status: LicenseStatus.notConfigured,
        message: 'แอปนี้ยังไม่ได้ฝังกุญแจตรวจใบอนุญาต',
      );
    }

    final String machine;
    try {
      machine = machineIdProvider();
    } catch (e) {
      return LicenseState(status: LicenseStatus.machineUnreadable, message: '$e');
    }

    final LicenseFile file;
    try {
      file = LicenseFile.parse(text);
    } on LicenseFormatException catch (e) {
      return LicenseState(
        status: LicenseStatus.invalid,
        machineId: machine,
        message: e.message,
      );
    }

    final previous = store.read();
    // เวลาที่เห็นล่าสุดต้องไม่ถอยหลัง ไม่งั้นใส่ใบใหม่ = ล้างการกันหมุนนาฬิกาทิ้ง
    final lastSeen = _latest(previous?.lastSeenUtc, _clock());
    final state = _evaluate(file, machine, lastSeen);
    if (state.status != LicenseStatus.active) return state;

    store.write(
      LicenseRecord(raw: file.raw, activatedAt: _clock(), lastSeenUtc: lastSeen),
    );
    return state;
  }

  LicenseState _evaluate(LicenseFile file, String machine, DateTime lastSeenUtc) {
    final payload = file.payload;

    if (payload.version > LicensePayload.currentVersion) {
      return LicenseState(
        status: LicenseStatus.invalid,
        machineId: machine,
        message: 'ใบอนุญาตนี้ออกจากโปรแกรมรุ่นใหม่กว่า',
      );
    }
    if (!verifier.verify(file)) {
      return LicenseState(
        status: LicenseStatus.invalid,
        machineId: machine,
        message: 'ลายเซ็นใบอนุญาตไม่ถูกต้อง',
      );
    }
    if (payload.machineId != machine) {
      return LicenseState(
        status: LicenseStatus.machineMismatch,
        payload: payload,
        machineId: machine,
        message: 'ใบอนุญาตนี้ออกให้เครื่องอื่น',
      );
    }

    final now = _clock();
    if (!payload.perpetual) {
      // นาฬิกาถอยหลังมีประโยชน์กับใบที่มีวันหมดอายุเท่านั้น ใบตลอดชีพจึงไม่ต้องเช็ค
      if (now.isBefore(lastSeenUtc.subtract(kClockSkewTolerance))) {
        return LicenseState(
          status: LicenseStatus.clockTampered,
          payload: payload,
          machineId: machine,
          message: 'เวลาของเครื่องย้อนหลังกว่าการใช้งานครั้งล่าสุด',
        );
      }
      if (now.isBefore(payload.issuedAt.subtract(const Duration(days: 1)))) {
        return LicenseState(
          status: LicenseStatus.clockTampered,
          payload: payload,
          machineId: machine,
          message: 'เวลาของเครื่องย้อนหลังกว่าวันที่ออกใบอนุญาต',
        );
      }
      final expires = payload.expiresAt!;
      if (!now.isBefore(expires)) {
        return LicenseState(
          status: LicenseStatus.expired,
          payload: payload,
          daysLeft: 0,
          machineId: machine,
          message: 'ใบอนุญาตหมดอายุแล้ว',
        );
      }
      final left = (expires.difference(now).inSeconds / Duration.secondsPerDay).ceil();
      return LicenseState(
        status: LicenseStatus.active,
        payload: payload,
        daysLeft: left,
        machineId: machine,
      );
    }

    return LicenseState(status: LicenseStatus.active, payload: payload, machineId: machine);
  }

  static DateTime _latest(DateTime? a, DateTime b) =>
      a == null || b.isAfter(a) ? b : a;
}
