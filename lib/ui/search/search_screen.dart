import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../preview/preview_pane.dart';
import '../widgets/common.dart';
import 'results_list.dart';
import 'search_panel.dart';

/// หน้าค้นหา — ซ้าย: ช่องค้น/ขอบเขต · กลาง: ไฟล์ที่พบ · ขวา: preview (เปิดเมื่อเลือกไฟล์)
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    final hasPreview = state.selectedFile != null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(d.pagePad * 0.6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: d.sidePanelW,
                child: const PanelCard(child: SearchPanel()),
              ),
              SizedBox(width: d.gapLg * 0.8),
              Expanded(
                flex: hasPreview ? 10 : 24,
                child: const ResultsList(),
              ),
              // preview เปิด/ปิดแบบลื่น ไม่กระชาก
              AnimatedSize(
                duration: Motion.base,
                curve: Motion.curve,
                child: hasPreview
                    ? SizedBox(width: d.gapLg * 0.8)
                    : const SizedBox.shrink(),
              ),
              if (hasPreview)
                Expanded(
                  flex: 14,
                  child: FadeSlideIn(
                    key: ValueKey(state.selectedFile!.path),
                    offsetY: 0,
                    child: const PreviewPane(),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: state.message == null
          ? null
          : Container(
              color: AppColors.surfaceMuted,
              padding: EdgeInsets.symmetric(
                horizontal: d.pagePad * 0.6,
                vertical: d.gap,
              ),
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
