import 'dart:convert';
import 'dart:typed_data';

import 'package:context_researcher_file/services/license/license_payload.dart';
import 'package:context_researcher_file/services/license/license_service.dart';
import 'package:context_researcher_file/services/license/license_store.dart';
import 'package:context_researcher_file/services/license/license_verifier.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter_test/flutter_test.dart';

/// เทสใช้คู่กุญแจที่สร้างสดในเทส ไม่ยุ่งกับกุญแจจริงของเจ้าของ
void main() {
  final pair = ed.generateKey();
  final publicB64 = base64.encode(pair.publicKey.bytes);
  const machine = '0123456789abcdef0123456789abcdef';
  final issued = DateTime.utc(2026, 1, 1);

  String makeLic({
    String mid = machine,
    int days = 30,
    DateTime? issuedAt,
    int version = LicensePayload.currentVersion,
    ed.PrivateKey? signWith,
  }) {
    final payload = LicensePayload(
      version: version,
      licenseId: 'test-1',
      machineId: mid,
      days: days,
      issuedAt: issuedAt ?? issued,
      name: 'ลูกค้าทดสอบ',
    );
    final bytes = payload.toCanonicalBytes();
    return LicenseFile.encode(bytes, ed.sign(signWith ?? pair.privateKey, bytes));
  }

  LicenseService serviceAt(
    DateTime now, {
    LicenseStore? store,
    String mid = machine,
    String? publicKey,
  }) => LicenseService(
    store: store ?? MemoryLicenseStore(),
    machineIdProvider: () => mid,
    verifier: LicenseVerifier(publicKeyBase64: publicKey ?? publicB64),
    clock: () => now,
  );

  test('ใบอนุญาตถูกต้อง: activate แล้วใช้งานได้ + นับวันคงเหลือถูก', () {
    final store = MemoryLicenseStore();
    final service = serviceAt(DateTime.utc(2026, 1, 11), store: store);
    final state = service.activateFromText(makeLic());

    expect(state.status, LicenseStatus.active);
    expect(state.daysLeft, 20);
    expect(state.payload?.name, 'ลูกค้าทดสอบ');
    expect(store.read(), isNotNull, reason: 'ต้องเก็บสถานะไว้ใช้รอบหน้า');
    expect(service.check().status, LicenseStatus.active);
  });

  test('days = 0 คือไม่มีวันหมดอายุ และไม่เข้าเงื่อนไขเตือนใกล้หมด', () {
    final store = MemoryLicenseStore();
    serviceAt(DateTime.utc(2026, 1, 2), store: store).activateFromText(makeLic(days: 0));
    // ผ่านไป 10 ปีก็ยังใช้ได้
    final later = serviceAt(DateTime.utc(2036, 1, 2), store: store).check();

    expect(later.status, LicenseStatus.active);
    expect(later.daysLeft, isNull);
    expect(later.perpetual, isTrue);
    expect(later.expiringSoon, isFalse);
  });

  test('เหลือ ≤ 7 วัน = ขึ้นสถานะเตือนล่วงหน้า', () {
    final store = MemoryLicenseStore();
    serviceAt(issued, store: store).activateFromText(makeLic());
    final near = serviceAt(DateTime.utc(2026, 1, 25), store: store).check();

    expect(near.status, LicenseStatus.active);
    expect(near.daysLeft, 6);
    expect(near.expiringSoon, isTrue);
  });

  test('แก้เนื้อใน payload แม้ตัวเดียว = ลายเซ็นไม่ผ่าน', () {
    final lic = jsonDecode(makeLic()) as Map<String, dynamic>;
    final payload = jsonDecode(utf8.decode(base64Url.decode('${lic['payload']}')));
    payload['days'] = 3650; // ยืดอายุเอง
    final tampered = jsonEncode({
      'payload': base64Url.encode(
        Uint8List.fromList(utf8.encode(jsonEncode(payload))),
      ),
      'sig': lic['sig'],
    });

    final state = serviceAt(DateTime.utc(2026, 1, 2)).activateFromText(tampered);
    expect(state.status, LicenseStatus.invalid);
  });

  test('ใบที่เซ็นด้วยกุญแจอื่น = ใช้ไม่ได้ (ออก key เองไม่ได้)', () {
    final other = ed.generateKey();
    final state = serviceAt(
      DateTime.utc(2026, 1, 2),
    ).activateFromText(makeLic(signWith: other.privateKey));

    expect(state.status, LicenseStatus.invalid);
  });

  test('ใบของเครื่องอื่น = machineMismatch และไม่ถูกบันทึก', () {
    final store = MemoryLicenseStore();
    final state = serviceAt(
      DateTime.utc(2026, 1, 2),
      store: store,
    ).activateFromText(makeLic(mid: 'ffffffffffffffffffffffffffffffff'));

    expect(state.status, LicenseStatus.machineMismatch);
    expect(store.read(), isNull);
  });

  test('หมดอายุแล้ว = ใช้ไม่ได้', () {
    final store = MemoryLicenseStore();
    serviceAt(issued, store: store).activateFromText(makeLic());
    final after = serviceAt(DateTime.utc(2026, 2, 15), store: store).check();

    expect(after.status, LicenseStatus.expired);
  });

  test('หมุนนาฬิกาถอยหลังเกิน 1 ชม. = ล็อก · ตั้งเวลากลับถูกแล้วใช้ได้ต่อ', () {
    final store = MemoryLicenseStore();
    serviceAt(DateTime.utc(2026, 1, 20), store: store).activateFromText(makeLic());

    final rolledBack = serviceAt(DateTime.utc(2026, 1, 5), store: store).check();
    expect(rolledBack.status, LicenseStatus.clockTampered);

    final fixed = serviceAt(DateTime.utc(2026, 1, 21), store: store).check();
    expect(fixed.status, LicenseStatus.active, reason: 'ไม่แบนถาวร ตั้งเวลากลับถูกต้องแล้วต้องใช้ได้');
  });

  test('ใบตลอดชีพไม่สนใจนาฬิกาที่ย้อนหลัง', () {
    final store = MemoryLicenseStore();
    serviceAt(DateTime.utc(2026, 1, 20), store: store).activateFromText(makeLic(days: 0));

    expect(serviceAt(DateTime.utc(2020, 1, 1), store: store).check().status, LicenseStatus.active);
  });

  test('ใส่ใบใหม่ไม่ล้างเวลาที่เห็นล่าสุด (กันเอาใบใหม่มารีเซ็ตการกันหมุนนาฬิกา)', () {
    final store = MemoryLicenseStore();
    serviceAt(DateTime.utc(2026, 1, 20), store: store).activateFromText(makeLic());
    final seen = store.read()!.lastSeenUtc;

    // ย้อนเวลาแล้วใส่ใบใหม่ที่ลายเซ็นถูกต้อง
    final state = serviceAt(
      DateTime.utc(2026, 1, 5),
      store: store,
    ).activateFromText(makeLic(issuedAt: DateTime.utc(2026, 1, 4)));

    expect(state.status, LicenseStatus.clockTampered);
    expect(store.read()!.lastSeenUtc, seen, reason: 'ของเดิมต้องไม่ถูกเขียนทับ');
  });

  test('ยังไม่เคยใส่ใบอนุญาต = none · อ่านรหัสเครื่องไม่ได้ = machineUnreadable', () {
    expect(serviceAt(DateTime.utc(2026, 1, 2)).check().status, LicenseStatus.none);

    final broken = LicenseService(
      store: MemoryLicenseStore(),
      machineIdProvider: () => throw Exception('อ่าน MachineGuid ไม่ได้'),
      verifier: LicenseVerifier(publicKeyBase64: publicB64),
      clock: () => DateTime.utc(2026, 1, 2),
    );
    expect(broken.check().status, LicenseStatus.machineUnreadable);
  });

  test('ยังไม่ฝัง public key = ไม่รับใบอนุญาตใด ๆ', () {
    final service = serviceAt(DateTime.utc(2026, 1, 2), publicKey: '');
    expect(service.check().status, LicenseStatus.notConfigured);
    expect(service.activateFromText(makeLic()).status, LicenseStatus.notConfigured);
  });

  test('ไฟล์ที่ไม่ใช่ใบอนุญาต = บอกว่าใช้ไม่ได้ ไม่ใช่ crash', () {
    expect(
      serviceAt(DateTime.utc(2026, 1, 2)).activateFromText('ไฟล์อะไรก็ไม่รู้').status,
      LicenseStatus.invalid,
    );
    expect(
      serviceAt(DateTime.utc(2026, 1, 2)).activateFromText('{"payload":"@@","sig":"@@"}').status,
      LicenseStatus.invalid,
    );
  });

  test('ใบจากรูปแบบรุ่นใหม่กว่า = ไม่รับ (กันตีความผิด)', () {
    final state = serviceAt(
      DateTime.utc(2026, 1, 2),
    ).activateFromText(makeLic(version: LicensePayload.currentVersion + 1));

    expect(state.status, LicenseStatus.invalid);
  });

  test('record เขียน/อ่านกลับได้ครบ', () {
    final record = LicenseRecord(
      raw: makeLic(),
      activatedAt: DateTime.utc(2026, 1, 2, 3, 4),
      lastSeenUtc: DateTime.utc(2026, 1, 3),
    );
    final back = LicenseRecord.fromJson(jsonDecode(jsonEncode(record.toJson())));

    expect(back.raw, record.raw);
    expect(back.activatedAt, record.activatedAt);
    expect(back.lastSeenUtc, record.lastSeenUtc);
  });
}
