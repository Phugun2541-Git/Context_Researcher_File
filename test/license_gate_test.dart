import 'dart:convert';
import 'dart:io';

import 'package:context_researcher_file/services/license/license_payload.dart';
import 'package:context_researcher_file/services/license/license_service.dart';
import 'package:context_researcher_file/services/license/license_store.dart';
import 'package:context_researcher_file/services/license/license_verifier.dart';
import 'package:context_researcher_file/ui/license/activate_screen.dart';
import 'package:context_researcher_file/ui/license/license_banner.dart';
import 'package:context_researcher_file/ui/license/license_gate.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pair = ed.generateKey();
  const machine = '0123456789abcdef0123456789abcdef';

  String makeLic({int days = 30}) {
    final payload = LicensePayload(
      version: LicensePayload.currentVersion,
      licenseId: 'gate-1',
      machineId: machine,
      days: days,
      issuedAt: DateTime.utc(2026, 1, 1),
      name: '',
    );
    final bytes = payload.toCanonicalBytes();
    return LicenseFile.encode(bytes, ed.sign(pair.privateKey, bytes));
  }

  LicenseService service(LicenseStore store, DateTime now) => LicenseService(
    store: store,
    machineIdProvider: () => machine,
    verifier: LicenseVerifier(publicKeyBase64: base64.encode(pair.publicKey.bytes)),
    clock: () => now,
  );

  // พื้นหลัง AuroraBackground เคลื่อนไหวไม่จบ ทำให้ pumpAndSettle ค้าง (กับดัก HANDOFF §9 ข้อ 4)
  Widget wrap(Widget child) => MaterialApp(
    home: MediaQuery(data: const MediaQueryData(disableAnimations: true), child: child),
  );

  testWidgets('ยังไม่มีใบอนุญาต = เห็นแต่หน้า activate · ใส่ไฟล์ถูกต้องแล้วเข้าแอปได้', (
    tester,
  ) async {
    final tmp = Directory.systemTemp.createTempSync('crf_gate');
    final licFile = File('${tmp.path}/test.lic')..writeAsStringSync(makeLic());
    final store = MemoryLicenseStore();
    late Future<void> Function(String) activate;

    await tester.pumpWidget(
      wrap(
        LicenseGate(
          service: service(store, DateTime.utc(2026, 1, 10)),
          lockedBuilder: (context, state, onPick) {
            activate = onPick;
            return ActivateScreen(state: state, onPick: onPick);
          },
          child: const Scaffold(body: Text('เนื้อแอป')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ActivateScreen), findsOneWidget);
    expect(find.text('เนื้อแอป'), findsNothing);

    await activate(licFile.path);
    await tester.pumpAndSettle();

    expect(find.text('เนื้อแอป'), findsOneWidget);
    expect(find.byType(ActivateScreen), findsNothing);

    tmp.deleteSync(recursive: true);
  });

  testWidgets('ใบใกล้หมดอายุ = หน้าแอปขึ้นแถบเตือน', (tester) async {
    final store = MemoryLicenseStore();
    service(store, DateTime.utc(2026, 1, 1)).activateFromText(makeLic());

    await tester.pumpWidget(
      wrap(
        LicenseGate(
          service: service(store, DateTime.utc(2026, 1, 27)),
          lockedBuilder: (context, state, onPick) =>
              ActivateScreen(state: state, onPick: onPick),
          child: const Scaffold(body: LicenseBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('ใบอนุญาตเหลืออีก 4 วัน'), findsOneWidget);
  });

  testWidgets('ใบหมดอายุ = กลับไปหน้า activate พร้อมบอกเหตุผล', (tester) async {
    final store = MemoryLicenseStore();
    service(store, DateTime.utc(2026, 1, 1)).activateFromText(makeLic());

    await tester.pumpWidget(
      wrap(
        LicenseGate(
          service: service(store, DateTime.utc(2026, 3, 1)),
          lockedBuilder: (context, state, onPick) =>
              ActivateScreen(state: state, onPick: onPick),
          child: const Scaffold(body: Text('เนื้อแอป')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ใบอนุญาตหมดอายุแล้ว'), findsOneWidget);
    expect(find.text('เนื้อแอป'), findsNothing);
  });
}
