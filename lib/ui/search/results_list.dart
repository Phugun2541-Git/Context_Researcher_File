import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../../domain/models.dart';
import '../../services/file_opener.dart';
import '../widgets/common.dart';

/// รายการไฟล์ที่พบคำค้น — 1 การ์ด = 1 ไฟล์ · chip = จุดที่พบ
class ResultsList extends StatelessWidget {
  const ResultsList({super.key});

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();

    if (!state.hasSearched) {
      return EmptyState(
        icon: Icons.search_outlined,
        title: 'พิมพ์คำที่จะค้นแล้วกดค้นหา',
        detail: state.mode == SearchMode.project
            ? 'ค้นจาก index ของโปรเจคนี้ · ไฟล์ที่แก้ใหม่จะถูก index ให้ก่อนค้นอัตโนมัติ'
            : 'โหมดนี้อ่านไฟล์สดทุกครั้ง ไม่เก็บ index',
      );
    }
    if (state.results.isEmpty) {
      return EmptyState(
        icon: state.searching ? Icons.hourglass_empty : Icons.sentiment_neutral_outlined,
        title: state.searching ? 'กำลังค้น…' : 'ไม่พบคำนี้ในขอบเขตที่เลือก',
        detail: state.searching
            ? null
            : 'ลองคำที่สั้นลง หรือเพิ่มโฟลเดอร์ในขอบเขตที่ค้น',
      );
    }

    final found = state.results.where((r) => r.totalHits > 0).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 2, bottom: d.gap),
          child: Text(
            'พบใน $found ไฟล์'
            '${state.searching ? ' · กำลังค้นต่อ…' : ''}',
            style: TextStyle(
              fontSize: d.fontSm,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(bottom: d.gapLg),
            itemCount: state.results.length,
            separatorBuilder: (_, __) => SizedBox(height: d.gap),
            itemBuilder: (context, i) => FadeSlideIn(
              delay: Motion.stagger(i),
              child: _FileResultCard(result: state.results[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _FileResultCard extends StatefulWidget {
  const _FileResultCard({required this.result});

  final FileResult result;

  @override
  State<_FileResultCard> createState() => _FileResultCardState();
}

class _FileResultCardState extends State<_FileResultCard> {
  bool _hover = false;
  bool _expanded = false;

  /// จำนวน chip ที่โชว์ก่อนกด "ดูทั้งหมด"
  static const _chipPreviewCount = 8;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    final r = widget.result;
    final selected = state.selectedFile?.path == r.path;

    // จุดที่พบ: รวม chip ที่ locator เดียวกัน (เช่นเจอหลายครั้งในหน้าเดียว)
    final uniqueHits = <String, SearchHit>{};
    for (final h in r.hits) {
      uniqueHits.putIfAbsent(h.locator.label, () => h);
    }
    final hits = uniqueHits.values.toList();
    final shown = _expanded ? hits : hits.take(_chipPreviewCount).toList();

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => state.selectFile(r),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.curve,
          padding: EdgeInsets.all(d.gapLg * 0.8),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(d.radiusLg),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : (_hover ? AppColors.textMuted.withValues(alpha: 0.35) : AppColors.border),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: r.path,
                      waitDuration: const Duration(milliseconds: 500),
                      child: Text(
                        r.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: d.fontBody + 0.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textStrong,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: d.gap),
                  KindBadge(kind: r.kind),
                  SizedBox(width: d.gap - 4),
                  if (r.totalHits > 0)
                    Text(
                      '${r.totalHits} จุด',
                      style: TextStyle(
                        fontSize: d.fontSm,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  IconButton(
                    tooltip: 'เปิดไฟล์ด้วยโปรแกรมของเครื่อง',
                    onPressed: () async {
                      final error = await FileOpener.open(r.path);
                      if (error != null) state.setMessage(error);
                    },
                    icon: Icon(Icons.open_in_new, size: d.iconSm),
                  ),
                  IconButton(
                    tooltip: 'เปิดโฟลเดอร์ที่เก็บไฟล์',
                    onPressed: () => FileOpener.revealInExplorer(r.path),
                    icon: Icon(Icons.folder_open_outlined, size: d.iconSm),
                  ),
                ],
              ),
              if (r.status != FileStatus.ok) ...[
                SizedBox(height: d.gap - 4),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: d.iconSm, color: AppColors.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        r.note ?? 'อ่านไฟล์นี้ไม่ได้',
                        style: TextStyle(fontSize: d.fontSm, color: AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ],
              if (hits.isNotEmpty) ...[
                SizedBox(height: d.gap),
                HighlightedText(
                  text: (state.selectedFile?.path == r.path
                          ? state.selectedHit
                          : null)
                      ?.snippet ??
                      hits.first.snippet,
                  start: (state.selectedFile?.path == r.path
                          ? state.selectedHit
                          : null)
                      ?.matchStart ??
                      hits.first.matchStart,
                  length: (state.selectedFile?.path == r.path
                          ? state.selectedHit
                          : null)
                      ?.matchLength ??
                      hits.first.matchLength,
                ),
                SizedBox(height: d.gap),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final hit in shown)
                      HitChip(
                        label: hit.locator.label,
                        selected: selected && state.selectedHit == hit,
                        onTap: () => state.selectHit(r, hit),
                      ),
                    if (hits.length > _chipPreviewCount)
                      HitChip(
                        label: _expanded
                            ? 'ย่อ'
                            : 'อีก ${hits.length - _chipPreviewCount} จุด',
                        selected: false,
                        onTap: () => setState(() => _expanded = !_expanded),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
