import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../preview/preview_pane.dart';
import '../widgets/common.dart';
import 'results_list.dart';
import 'search_panel.dart';

/// พื้นที่ทำงานของการค้นหา — ซ้าย: แผงค้น · กลาง: ผล · ขวา: preview (เปิดเมื่อเลือกไฟล์)
/// ใช้ร่วมกันทั้งหน้าหลัก (ค้นด่วน) และหน้าโปรเจค
class SearchWorkspace extends StatelessWidget {
  const SearchWorkspace({super.key, required this.title, this.subtitle, this.emptyChild});

  final String title;
  final String? subtitle;

  /// สิ่งที่แสดงกลางจอตอนยังไม่ได้ค้น (หน้าหลักใช้โชว์ไฟล์ล่าสุด)
  final Widget? emptyChild;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    final hasPreview = state.selectedFile != null;

    return Padding(
      padding: EdgeInsets.all(d.pagePad * 0.6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // จอแคบ: 3 คอลัมน์แล้วแต่ละช่องเล็กเกินอ่าน → ให้ preview เปิดทับผลค้นหาแทน
          final stacked = constraints.maxWidth < 1000;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: stacked ? d.rw(26).clamp(250, 300) : d.sidePanelW,
                child: PanelCard(child: SearchPanel(title: title, subtitle: subtitle)),
              ),
              SizedBox(width: d.gapLg * 0.8),
              if (stacked)
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: ResultsList(emptyChild: emptyChild)),
                      if (hasPreview)
                        Positioned.fill(
                          child: FadeSlideIn(
                            key: ValueKey(state.selectedFile!.path),
                            offsetY: 8,
                            child: const PreviewPane(),
                          ),
                        ),
                    ],
                  ),
                )
              else ...[
                Expanded(flex: hasPreview ? 10 : 24, child: ResultsList(emptyChild: emptyChild)),
                if (hasPreview) ...[
                  SizedBox(width: d.gapLg * 0.8),
                  Expanded(
                    flex: 14,
                    child: FadeSlideIn(
                      key: ValueKey(state.selectedFile!.path),
                      offsetY: 0,
                      child: const PreviewPane(),
                    ),
                  ),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}
