import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../home/home_screen.dart';
import '../projects/new_project_dialog.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/aurora_background.dart';
import 'nav_sidebar.dart';

/// โครงหน้าจอหลัก — แถบเมนูซ้ายคงที่ ด้านขวาสลับหน้าตามเมนูที่เลือก
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();

    return Scaffold(
      body: AuroraBackground(
        intensity: 0.4,
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NavSidebar(onNewProject: () => createProjectFlow(context)),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.base,
                  child: switch (state.page) {
                    AppPage.home => const HomeScreen(key: ValueKey('home')),
                    AppPage.project => SearchScreen(
                      key: ValueKey('project-${state.currentProject?.id}'),
                    ),
                    AppPage.settings => const SettingsScreen(key: ValueKey('settings')),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      // แถบข้อความแจ้งผล/ข้อผิดพลาด อยู่ระดับ shell จึงเห็นได้ทุกหน้า
      bottomNavigationBar: state.message == null
          ? null
          : Container(
              color: AppColors.surfaceMuted,
              padding: EdgeInsets.symmetric(horizontal: d.pagePad * 0.6, vertical: d.gap),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: d.iconSm, color: AppColors.textMuted),
                  SizedBox(width: d.gap),
                  Expanded(
                    child: Text(
                      state.message!,
                      style: TextStyle(fontSize: d.fontSm, color: AppColors.textBody),
                    ),
                  ),
                  InkWell(
                    onTap: () => state.setMessage(null),
                    child: Icon(Icons.close, size: d.iconSm, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
    );
  }
}
