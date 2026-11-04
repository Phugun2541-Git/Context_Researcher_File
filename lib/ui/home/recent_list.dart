import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../../domain/models.dart';
import '../../services/file_opener.dart';
import '../../services/user_folders.dart';
import '../widgets/common.dart';

/// ไฟล์ที่เพิ่งเปิดล่าสุด — แสดงกลางหน้าหลักตอนยังไม่ได้ค้น
class RecentList extends StatelessWidget {
  const RecentList({super.key});

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    final recents = state.recents;

    final hasMyFiles = state.projects.any((p) => p.name == UserFolders.myFilesProjectName);

    if (recents.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!hasMyFiles) const _MyFilesCard(),
          const Expanded(
            child: EmptyState(
              icon: Icons.search_outlined,
              title: 'พิมพ์คำที่จะค้นแล้วกดค้นหา',
              detail: 'เลือกโฟลเดอร์ที่จะค้นในแผงซ้ายก่อน · ไฟล์ที่เคยเปิดจะมาโผล่ตรงนี้',
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hasMyFiles) const _MyFilesCard(),
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

/// ทางลัดสำหรับเคส "จำไม่ได้ว่าไฟล์อยู่ไหน" — ผูกโฟลเดอร์เอกสารมาตรฐานให้ในคลิกเดียว
class _MyFilesCard extends StatelessWidget {
  const _MyFilesCard();

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.read<AppState>();
    return Container(
      margin: EdgeInsets.only(bottom: d.gap),
      padding: EdgeInsets.all(d.gapLg * 0.8),
      decoration: BoxDecoration(
        color: AppColors.accentSurface,
        borderRadius: BorderRadius.circular(d.radiusLg),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_outlined, size: d.icon, color: AppColors.accent),
          SizedBox(width: d.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'จำไม่ได้ว่าไฟล์อยู่โฟลเดอร์ไหน?',
                  style: TextStyle(
                    fontSize: d.fontBody,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textStrong,
                  ),
                ),
                Text(
                  'สร้างโปรเจค "${UserFolders.myFilesProjectName}" ที่ผูก Desktop · Documents · '
                  'Downloads · OneDrive ให้เลย (ครั้งแรกใช้เวลาอ่านไฟล์สักพัก)',
                  style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted, height: 1.4),
                ),
              ],
            ),
          ),
          SizedBox(width: d.gap),
          FilledButton(
            onPressed: state.openOrCreateMyFiles,
            child: const Text('สร้างให้'),
          ),
        ],
      ),
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
