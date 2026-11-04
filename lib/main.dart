import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';

import 'app/app.dart';
import 'app/app_state.dart';
import 'data/db.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // PDFium (pdfrx) ต้อง init บน main isolate ก่อนใช้ทั้ง extract และ viewer
  await pdfrxFlutterInitialize();
  final db = await AppDb.open();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(db),
      child: const App(),
    ),
  );
}
