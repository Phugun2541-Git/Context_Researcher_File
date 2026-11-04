import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../../domain/models.dart';
import '../../services/file_opener.dart';
import '../widgets/common.dart';

/// ไฟล์ที่เพิ่งเปิดล่าสุด — แสดงกลางหน้าหลักตอนยังไม่ได้ค้น
class RecentList extends StatelessWidget {
  const RecentList({super.key});

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    final recents = state.recents;

    if (recents.isEmpty) {
      return const EmptyState(
        icon: Icons.search_outlined,
        title: 'พิมพ์คำที่จะค้นแล้วกดค้นหา',
        detail: 'เลือกโฟลเดอร์ที่จะค้นในแผงซ้ายก่อน · ไฟล์ที่เคยเปิดจะมาโผล่ตรงนี้',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 2, bottom: d.gap),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'เปิดล่าสุด',
                  style: TextStyle(
                    fontSize: d.fontBody,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
              ),
              TextButton(
                onPressed: state.clearRecents,
                child: Text('ล้างรายการ', style: TextStyle(fontSize: d.fontSm)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(bottom: d.gapLg),
            itemCount: recents.length,
            separatorBuilder: (_, __) => SizedBox(height: d.gap - 4),
            itemBuilder: (context, i) => FadeSlideIn(
              delay: Motion.stagger(i),
              offsetY: 6,
              child: _RecentRow(item: recents[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentRow extends StatefulWidget {
  const _RecentRow({required this.item});

  final RecentFile item;

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.read<AppState>();
    final item = widget.item;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        // กดแล้วค้นคำเดิมซ้ำ เพื่อกลับไปจุดที่เคยอ่านได้เร็ว ๆ
        onTap: item.query == null || item.query!.isEmpty
            ? null
            : () {
                state.setQuery(item.query!);
                state.runSearch();
              },
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: EdgeInsets.all(d.gap),
          decoration: BoxDecoration(
            color: _hover ? AppColors.accentSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(d.radiusLg),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              FileKindTile(kind: item.kind),
              SizedBox(width: d.gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: d.fontBody,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textStrong,
                      ),
                    ),
                    Text(
                      item.query == null || item.query!.isEmpty
                          ? item.path
                          : 'เคยค้น "${item.query}" · ${item.path}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              SizedBox(width: d.gap),
              Text(
                shortDateLabel(item.openedAt.millisecondsSinceEpoch),
                style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
              ),
              SizedBox(width: d.gap - 4),
              AsyncIconButton(
                tooltip: 'เปิดไฟล์ด้วยโปรแกรมของเครื่อง',
                icon: Icons.open_in_new,
                onPressed: () async {
                  final error = await FileOpener.open(item.path);
                  if (error != null) state.setMessage(error);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
