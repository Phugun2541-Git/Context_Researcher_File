import 'dart:io';

import 'package:context_researcher_file/app/app_state.dart';
import 'package:context_researcher_file/app/theme/app_theme.dart';
import 'package:context_researcher_file/app/theme/motion.dart';
import 'package:context_researcher_file/data/db.dart';
import 'package:context_researcher_file/ui/search/search_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// เทสว่าผลค้นหาวาดออกมาได้จริง
///
/// จับบั๊กชนิดที่ analyze ไม่เห็น เช่น BoxDecoration ที่ assert ตอน paint
/// (ขอบสีไม่เท่ากันทุกด้าน + borderRadius) ซึ่งทำให้การ์ดโผล่มาเป็นกล่องเปล่า
void main() {
  testWidgets('การ์ดผลค้นหาวาดครบ: ชื่อไฟล์ จำนวนจุด และ chip ตำแหน่ง',
      (tester) async {
    Motion.reduced = true;
    addTearDown(() => Motion.reduced = false);

    final tmp = Directory.systemTemp.createTempSync('crf_render');
    final db = await AppDb.open(overridePath: '${tmp.path}/index.db');
    final state = AppState(db);
    addTearDown(() {
      state.dispose();
      db.dispose();
      tmp.deleteSync(recursive: true);
    });

    final id = state.createProject('RMA');
    state.openProject(state.projects.firstWhere((p) => p.id == id));
    state.addRoots(['test/fixtures']);
    state.setQuery('RMA');
    // อ่านไฟล์จริง/Isolate ต้องรันนอก fake async ของ flutter_test
    await tester.runAsync(() => state.runSearch());
    expect(state.results, isNotEmpty);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: SearchScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('พบใน 4 ไฟล์'), findsOneWidget);
    expect(find.text('sample.txt'), findsOneWidget);
    expect(find.text('sample.xlsx'), findsOneWidget);
    // chip ตำแหน่งต้องโผล่ (ยืนยันว่าเนื้อในการ์ดถูกวาด ไม่ใช่กล่องเปล่า)
    expect(find.text('บรรทัด 3'), findsOneWidget);
    expect(find.text('ใบเสนอราคา!B12'), findsOneWidget);
    expect(find.text('3 จุด'), findsWidgets);
  });
}
