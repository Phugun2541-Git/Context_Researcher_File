import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../../domain/models.dart';
import '../../services/file_opener.dart';
import '../widgets/common.dart';
import 'lines_preview.dart';
import 'pdf_preview.dart';
import 'sheet_preview.dart';

/// แผงขวา — หัวไฟล์ + 2 แท็บ: เนื้อไฟล์ (preview) กับ รายการจุดที่พบทั้งหมด
class PreviewPane extends StatefulWidget {
  const PreviewPane({super.key});

  @override
  State<PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends State<PreviewPane> {
  bool _showMatches = false;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    final file = state.selectedFile;
    if (file == null) return const SizedBox.shrink();

    final scanned = state.scannedFileFor(file.path);
    final hit = state.selectedHit;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(d.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── หัว preview: ไอคอนชนิดไฟล์ + ชื่อ/ที่อยู่ + ปุ่มเปิดไฟล์จริง ──
          Padding(
            padding: EdgeInsets.fromLTRB(d.gapLg * 0.7, d.gap, d.gapLg * 0.7, 0),
            child: Row(
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
                          fontSize: d.fontBody + 1,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textStrong,
                        ),
                      ),
                      Tooltip(
                        message: file.path,
                        child: Text(
                          file.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                // Excel: สั่ง cursor ในไฟล์จริงให้ไปจ่อ cell ไม่ได้ → ให้ copy ref ไปวางใน Name Box
                if (hit != null && file.kind == FileKind.xlsx)
                  AsyncIconButton(
                    tooltip: 'คัดลอก ${hit.locator.label} (วางในช่อง Name Box ของ Excel)',
                    icon: Icons.copy_all_outlined,
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: hit.locator.label));
                      state.setMessage('คัดลอก ${hit.locator.label} แล้ว');
                    },
                  ),
                AsyncIconButton(
                  tooltip: 'เปิดไฟล์ด้วยโปรแกรมของเครื่อง',
                  icon: Icons.open_in_new,
                  onPressed: () async {
                    final error = await FileOpener.open(file.path);
                    if (error != null) state.setMessage(error);
                  },
                ),
                AsyncIconButton(
                  tooltip: 'เปิดโฟลเดอร์ที่เก็บไฟล์',
                  icon: Icons.folder_open_outlined,
                  onPressed: () async => FileOpener.revealInExplorer(file.path),
                ),
                IconButton(
                  tooltip: 'ปิด preview',
                  onPressed: state.clearSelection,
                  icon: Icon(Icons.close, size: d.iconSm),
                ),
              ],
            ),
          ),

          // ── แท็บ ──
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            padding: EdgeInsets.symmetric(horizontal: d.gapLg * 0.7),
            child: Row(
              children: [
                _Tab(
                  label: 'เนื้อไฟล์',
                  selected: !_showMatches,
                  onTap: () => setState(() => _showMatches = false),
                ),
                SizedBox(width: d.gapLg),
                _Tab(
                  label: 'จุดที่พบ (${file.totalHits})',
                  selected: _showMatches,
                  onTap: () => setState(() => _showMatches = true),
                ),
              ],
            ),
          ),

          Expanded(
            child: _showMatches
                ? _MatchesTab(
                    file: file,
                    onPick: (picked) {
                      state.selectHit(file, picked);
                      setState(() => _showMatches = false);
                    },
                  )
                : scanned == null
                ? const EmptyState(icon: Icons.error_outline, title: 'ไม่พบไฟล์นี้ในเครื่องแล้ว')
                : switch (file.kind) {
                    FileKind.pdf => PdfPreview(
                      path: file.path,
                      query: state.query.trim(),
                      page: hit?.locator.page,
                    ),
                    FileKind.xlsx => SheetPreview(
                      file: scanned,
                      query: state.query.trim(),
                      target: hit?.locator,
                    ),
                    _ => LinesPreview(
                      file: scanned,
                      query: state.query.trim(),
                      target: hit?.locator,
                    ),
                  },
          ),
        ],
      ),
    );
  }
}

/// แท็บแบบขีดเส้นใต้
class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: EdgeInsets.symmetric(vertical: d.gap),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? AppColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: d.fontSm,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.accent : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// รายการจุดที่พบทั้งหมดในไฟล์นี้ — กดแล้วกระโดดไปจุดนั้นในแท็บเนื้อไฟล์
class _MatchesTab extends StatelessWidget {
  const _MatchesTab({required this.file, required this.onPick});

  final FileResult file;
  final void Function(SearchHit hit) onPick;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    if (file.hits.isEmpty) {
      return const EmptyState(icon: Icons.search_off_outlined, title: 'ไม่มีจุดที่พบในไฟล์นี้');
    }
    return ListView.separated(
      padding: EdgeInsets.all(d.gapLg * 0.7),
      itemCount: file.hits.length,
      separatorBuilder: (_, __) => SizedBox(height: d.gap - 4),
      itemBuilder: (context, i) {
        final hit = file.hits[i];
        final selected = state.selectedHit == hit;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => onPick(hit),
            child: Container(
              padding: EdgeInsets.all(d.gap),
              decoration: BoxDecoration(
                color: selected ? AppColors.accentSurface : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(d.radius),
                border: Border.all(color: selected ? AppColors.accent : AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hit.locator.label,
                    style: TextStyle(
                      fontSize: d.fontSm,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  HighlightedText(
                    text: hit.snippet,
                    start: hit.matchStart,
                    length: hit.matchLength,
                    fontSize: d.fontSm,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
