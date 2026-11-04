import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ui/license/activate_screen.dart';
import '../ui/license/license_gate.dart';
import '../ui/shell/app_shell.dart';
import 'app_state.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final fontScale = context.select<AppState, double>((s) => s.settings.fontScale);
    // ฟัง themeNotifier เพื่อ rebuild ทั้งแอปตอนสลับธีมโดยไม่ต้องแตะ call site ของสี
    return ValueListenableBuilder<String>(
      valueListenable: themeNotifier,
      builder: (context, themeId, _) => MaterialApp(
        title: 'Context Researcher',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(fontScale)),
          child: child!,
        ),
        home: LicenseGate(
          lockedBuilder: (context, state, activate) =>
              ActivateScreen(state: state, onPick: activate),
          child: const AppShell(),
        ),
      ),
    );
  }
}
