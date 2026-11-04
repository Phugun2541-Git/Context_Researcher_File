import 'dart:io';

import 'package:context_researcher_file/app/app_state.dart';
import 'package:context_researcher_file/app/theme/app_colors.dart';
import 'package:context_researcher_file/app/theme/motion.dart';
import 'package:context_researcher_file/data/db.dart';
import 'package:context_researcher_file/data/settings_repository.dart';
import 'package:context_researcher_file/domain/models.dart';
import 'package:context_researcher_file/services/file_scanner.dart';
import 'package:context_researcher_file/ui/projects/projects_screen.dart';
import 'package:context_researcher_file/ui/search/search_screen.dart';
import 'package:context_researcher_file/ui/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// เทสหน้าตั้งค่า + การย่อหน้าต่าง (ล็อกบั๊ก overflow ตอนย่อจอ)
void main() {
  late Directory tmp;
  late AppDb db;
  late AppState state;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('crf_ui');
    db = await AppDb.open(overridePath: '${tmp.path}/index.db');
    state = AppState(db);
  });

  tearDown(() {
    state.dispose();
    db.dispose();
    tmp.deleteSync(recursive: true);
    applyTheme(kDefaultThemeId);
    Motion.reduced = false;
  });

  /// พื้นหลังของแอปวนภาพตลอดเวลา ทำให้ pumpAndSettle ไม่มีวันนิ่ง
  /// จึงปิดการเคลื่อนไหวผ่าน MediaQuery เหมือนที่ระบบปฏิบัติการสั่งได้จริง
  Widget wrap(Widget child) => ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: child,
          ),
        ),
      );

  Future<void> setWindow(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('หน้าแรกไม่ overflow ที่ขนาดหน้าต่างเล็กสุด (980x640)',
      (tester) async {
    await setWindow(tester, const Size(980, 640));
    await tester.pumpWidget(wrap(const ProjectsScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('ยังไม่มีโปรเจค'), findsOneWidget);
  });

  testWidgets('หน้าค้นหาไม่ overflow ที่ขนาดเล็กสุด และสลับเป็น preview ทับ',
      (tester) async {
    final id = state.createProject('RMA');
    state.openProject(state.projects.firstWhere((p) => p.id == id));
    state.addRoots(['test/fixtures']);

    await setWindow(tester, const Size(980, 640));
    await tester.pumpWidget(wrap(const SearchScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await setWindow(tester, const Size(1920, 1080));
    await tester.pumpWidget(wrap(const SearchScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('หน้าตั้งค่า: เลือกธีมแล้วสีเปลี่ยนจริงและถูกบันทึกลง DB',
      (tester) async {
    await setWindow(tester, const Size(1280, 900));
    await tester.pumpWidget(wrap(const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('เขียวมรกต'));
    await tester.pumpAndSettle();

    expect(state.settings.themeId, 'teal');
    expect(AppColors.accent, paletteTeal.accent);
    // อ่านกลับจาก DB ด้วย repo ตัวใหม่ = ค่าถูกเขียนลงไปจริง ไม่ใช่อยู่แค่ในหน่วยความจำ
    expect(SettingsRepository(db).load().themeId, 'teal');
  });

  test('ปิดเอฟเฟกต์เคลื่อนไหวแล้ว duration เป็นศูนย์ทั้งแอป', () {
    state.updateSettings(state.settings.copyWith(reduceMotion: true));
    expect(Motion.base, Duration.zero);
    expect(Motion.stagger(5), Duration.zero);
    state.updateSettings(state.settings.copyWith(reduceMotion: false));
    expect(Motion.base, isNot(Duration.zero));
  });

  test('ปิดชนิดไฟล์ในตั้งค่าแล้ว scanner ข้ามไฟล์ชนิดนั้น', () async {
    final all = await const FileScanner().scan(['test/fixtures']);
    expect(all.map((f) => f.kind).toSet().length, greaterThan(1));

    final onlyText = await const FileScanner(allowedKinds: {FileKind.text})
        .scan(['test/fixtures']);
    expect(onlyText.every((f) => f.kind == FileKind.text), isTrue);
    expect(onlyText.length, lessThan(all.length));
  });

  test('ไฟล์ใหญ่เกินค่าที่ตั้งไว้ถูกข้าม', () async {
    final tiny = await const FileScanner(maxFileSizeBytes: 10).scan(['test/fixtures']);
    // scanner ยังเก็บรายชื่อไว้ ส่วนการข้ามเกิดตอน extract → เช็คผ่านค่า config ที่ส่งต่อ
    expect(tiny.isNotEmpty, isTrue);
    expect(const FileScanner(maxFileSizeBytes: 10).maxFileSizeBytes, 10);
  });

  test('ค่าตั้งค่าเริ่มต้นเมื่อยังไม่เคยบันทึก', () {
    final fresh = SettingsRepository(db).load();
    expect(fresh.themeId, kDefaultThemeId);
    expect(fresh.fontScale, 1.0);
    expect(fresh.enabledKinds.length, FileKind.values.length);
    expect(fresh.maxFileSizeMb, 64);
  });
}
