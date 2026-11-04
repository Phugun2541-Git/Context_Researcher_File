@Tags(['shots'])
library;

import 'dart:io';

import 'package:context_researcher_file/app/app_state.dart';
import 'package:context_researcher_file/app/theme/app_theme.dart';
import 'package:context_researcher_file/app/theme/motion.dart';
import 'package:context_researcher_file/data/db.dart';
import 'package:context_researcher_file/services/license/license_service.dart';
import 'package:context_researcher_file/ui/license/activate_screen.dart';
import 'package:context_researcher_file/ui/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// เรนเดอร์หน้าจอเป็นภาพไว้ตรวจงานออกแบบด้วยตา (ไม่ใช่เทสที่ต้องผ่าน)
///
/// รัน: flutter test test/snapshot_test.dart --tags shots --update-goldens
/// ภาพออกที่ test/shots/ · ผลต่างเล็กน้อยระหว่างเครื่องเป็นเรื่องปกติ จึงไม่รวมในชุดเทสปกติ
void main() {
  setUpAll(() async {
    // ปิดอนิเมชันของแอปเอง ไม่งั้นภาพถูกถ่ายตอน fade ยังไม่จบ
    Motion.reduced = true;
    final loader = FontLoader('Anuphan');
    for (final f in [
      'assets/fonts/Anuphan-Regular.ttf',
      'assets/fonts/Anuphan-Medium.ttf',
      'assets/fonts/Anuphan-SemiBold.ttf',
      'assets/fonts/Anuphan-Bold.ttf',
    ]) {
      loader.addFont(
        File(f).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    }
    await loader.load();
  });

  // ไม่รันในชุดเทสปกติ เพราะภาพต่างกันเล็กน้อยตามเครื่อง/ฟอนต์
  final enabled = Platform.environment['RENDER_SHOTS'] == '1';

  testWidgets('snapshot', skip: !enabled, (tester) async {
    final tmp = Directory.systemTemp.createTempSync('crf_shot');
    final db = await AppDb.open(overridePath: '${tmp.path}/index.db');
    final state = AppState(db);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Widget wrap(Widget child) => ChangeNotifierProvider.value(
          value: state,
          child: MaterialApp(
            theme: buildAppTheme(),
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: child,
            ),
          ),
        );

    await tester.pumpWidget(wrap(const AppShell()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('shots/home_empty.png'),
    );

    final id = state.createProject('RMA');
    state.openProject(state.projects.firstWhere((p) => p.id == id));
    state.addRoots(['test/fixtures']);
    await tester.pumpWidget(wrap(const AppShell()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('shots/project_search.png'),
    );

    state.setQuery('RMA');
    // งานจริง (อ่านไฟล์/Isolate) ต้องรันนอก fake async ของ flutter_test
    await tester.runAsync(() => state.runSearch());
    await tester.pumpWidget(wrap(const AppShell()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('shots/search_results.png'),
    );

    if (state.results.isNotEmpty) {
      state.selectFile(state.results.first);
      await tester.pumpWidget(wrap(const AppShell()));
      await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: 1)));
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AppShell),
        matchesGoldenFile('shots/search_preview.png'),
      );
    }

    state.goSettings();
    await tester.pumpWidget(wrap(const AppShell()));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('shots/settings.png'),
    );

    // เลื่อนลงท้ายหน้า เพื่อเห็นบล็อก "เกี่ยวกับ" (เวอร์ชัน + อีเมลติดต่อ)
    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(AppShell),
      matchesGoldenFile('shots/settings_about.png'),
    );

    // หน้าล็อก (ยังไม่ได้ใส่ใบอนุญาต)
    await tester.pumpWidget(
      wrap(
        ActivateScreen(
          state: const LicenseState(
            status: LicenseStatus.none,
            machineId: '0123456789abcdef0123456789abcdef',
          ),
          onPick: (_) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ActivateScreen),
      matchesGoldenFile('shots/license_activate.png'),
    );

    db.dispose();
    tmp.deleteSync(recursive: true);
  });
}
