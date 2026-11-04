import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/motion.dart';
import '../../domain/models.dart';
import '../widgets/common.dart';

/// รายการไฟล์ที่พบคำค้น — 1 การ์ด = 1 ไฟล์ · chip = จุดที่พบ
class ResultsList extends StatelessWidget {
  const ResultsList({super.key, this.emptyChild});

  /// สิ่งที่แสดงตอนยังไม่ได้ค้น (หน้าหลักส่งรายการไฟล์ล่าสุดมา)
  final Widget? emptyChild;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();

    if (!state.hasSearched) {
      return emptyChild ??
          EmptyState(
            icon: Icons.search_outlined,
            title: 'พิมพ์คำที่จะค้นแล้วกดค้นหา',
            detail: state.mode == SearchMode.project
                ? 'ไฟล์ที่แก้ใหม่จะถูกอ่านซ้ำให้เองก่อนค้น'
                : 'โหมดนี้อ่านไฟล์สดทุกครั้ง ไม่เก็บ index',
          );
    }
    if (state.results.isEmpty) {
      return EmptyState(
        icon: state.searching ? Icons.hourglass_empty : Icons.sentiment_neutral_outlined,
        title: state.searching ? 'กำลังค้น…' : 'ไม่พบคำนี้ในขอบเขตที่เลือก',
        detail: state.searching ? null : 'ลองคำสั้นลง หรือเพิ่มโฟลเดอร์',
      );
    }

    final results = state.sortedResults;
    final found = results.where((r) => r.totalHits > 0).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 2, bottom: d.gap),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'ผลการค้นหา ',
                        style: TextStyle(
                          fontSize: d.fontBody + 1,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textStrong,
                        ),
                      ),
                      TextSpan(
                        text: '($found ไฟล์)${state.searching ? ' · กำลังค้นต่อ…' : ''}',
                        style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const _SortDropdown(),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.only(bottom: d.gapLg),
            itemCount: results.length,
            separatorBuilder: (_, __) => SizedBox(height: d.gap),
            itemBuilder: (context, i) => FadeSlideIn(
              delay: Motion.stagger(i),
              offsetY: 6,
              child: _ResultCard(result: results[i]),
            ),
          ),
        ),
      ],
    );
  }
}

/// ตัวเลือกการเรียงผล
class _SortDropdown extends StatelessWidget {
  const _SortDropdown();

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: d.gap, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(d.radiusPill),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<ResultSort>(
        value: state.sort,
        isDense: true,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(d.radius),
        icon: Icon(Icons.expand_more, size: d.iconSm, color: AppColors.textMuted),
        // DropdownButton ไม่สืบทอด DefaultTextStyle → ต้องระบุฟอนต์เอง ไม่งั้นไทยเป็นสี่เหลี่ยม
        style: TextStyle(fontSize: d.fontSm, color: AppColors.textBody, fontFamily: kFontFamily),
        items: [
          for (final option in ResultSort.values)
            DropdownMenuItem(
              value: option,
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: d.fontSm,
                  color: AppColors.textBody,
                  fontFamily: kFontFamily,
                ),
              ),
            ),
        ],
        onChanged: (value) => value == null ? null : state.setSort(value),
      ),
    );
  }
}

class _ResultCard extends StatefulWidget {
  const _ResultCard({required this.result});

  final FileResult result;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    final file = widget.result;
    final selected = state.selectedFile?.path == file.path;
    final scanned = file.status == FileStatus.noText;
    final date = shortDateLabel(file.mtimeMs);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => state.selectFile(file),
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.curve,
          decoration: BoxDecoration(
            color: selected ? AppColors.accentSurface : AppColors.surface,
            borderRadius: BorderRadius.circular(d.radiusLg),
            border: Border.all(
              color: selected
                  ? AppColors.accent
                  : (_hover ? AppColors.accent.withValues(alpha: 0.4) : AppColors.border),
            ),
          ),
          child: ClipRRect(
            // แถบสีชนิดไฟล์เป็นลูกที่ clip ตามมุมการ์ด — ห้ามทำเป็น Border สีไม่เท่ากันทุกด้าน
            // เพราะคู่กับ borderRadius แล้ว Flutter assert ตอน paint และวาดลูกไม่ออกทั้งใบ
            borderRadius: BorderRadius.circular(d.radiusLg - 1),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: colorOfKind(file.kind)),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(d.gap + 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FileKindTile(kind: file.kind),
                              SizedBox(width: d.gap),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      file.fileName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: d.fontBody,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textStrong,
                                      ),
                                    ),
                                    Text(
                                      file.path,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: d.fontSm,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: d.gap),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (date.isNotEmpty)
                                    Text(
                                      date,
                                      style: TextStyle(
                                        fontSize: d.fontSm,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  Text(
                                    scanned ? 'ค้นไม่ได้' : '${file.totalHits} จุด',
                                    style: TextStyle(
                                      fontSize: d.fontSm,
                                      fontWeight: FontWeight.w700,
                                      color: scanned ? AppColors.warning : AppColors.accent,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: d.gap - 4),
                              Icon(
                                Icons.chevron_right,
                                size: d.icon,
                                color: selected ? AppColors.accent : AppColors.textMuted,
                              ),
                            ],
                          ),
                          if (scanned) ...[
                            SizedBox(height: d.gap - 2),
                            Text(
                              file.note ?? 'ไฟล์สแกน ไม่มีชั้นข้อความให้ค้น',
                              style: TextStyle(fontSize: d.fontSm, color: AppColors.warning),
                            ),
                          ] else if (file.hits.isNotEmpty) ...[
                            SizedBox(height: d.gap - 2),
                            HighlightedText(
                              text: file.hits.first.snippet,
                              start: file.hits.first.matchStart,
                              length: file.hits.first.matchLength,
                              maxLines: 1,
                              fontSize: d.fontSm,
                            ),
                            SizedBox(height: d.gap - 2),
                            Wrap(
                              spacing: d.gap - 4,
                              runSpacing: d.gap - 6,
                              children: [
                                for (final hit in file.hits.take(4))
                                  HitChip(
                                    label: hit.locator.label,
                                    selected: selected && state.selectedHit == hit,
                                    onTap: () => state.selectHit(file, hit),
                                  ),
                                if (file.hits.length > 4)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '+${file.hits.length - 4}',
                                      style: TextStyle(
                                        fontSize: d.fontSm,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
