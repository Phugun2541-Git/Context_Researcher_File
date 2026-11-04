import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../domain/models.dart';
import '../../services/file_opener.dart';
import '../widgets/common.dart';
import 'lines_preview.dart';
import 'sheet_preview.dart';
import 'pdf_preview.dart';

/// แผงขวา — preview ไฟล์ที่เลือก + ปุ่มเปิดไฟล์จริง
class PreviewPane extends StatelessWidget {
  const PreviewPane({super.key});

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
          // ── หัว preview ──
          Container(
            padding: EdgeInsets.symmetric(horizontal: d.gapLg * 0.7, vertical: d.gap - 2),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                KindBadge(kind: file.kind),
                SizedBox(width: d.gap),
                Expanded(
                  child: Tooltip(
                    message: file.path,
                    child: Text(
                      file.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: d.fontBody,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textStrong,
                      ),
                    ),
                  ),
                ),
                if (hit != null) ...[
                  Text(
                    hit.locator.label,
                    style: TextStyle(fontSize: d.fontSm, color: AppColors.accent),
                  ),
                  // Excel: เปิดไฟล์จริงแล้วสั่ง cursor ไปจ่อ cell ไม่ได้ → ให้ copy ref ไปวางใน Name Box
                  if (file.kind == FileKind.xlsx)
                    AsyncIconButton(
                      tooltip: 'คัดลอก ${hit.locator.label} (วางในช่อง Name Box ของ Excel)',
                      icon: Icons.copy_all_outlined,
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: hit.locator.label),
                        );
                        state.setMessage('คัดลอก ${hit.locator.label} แล้ว');
                      },
                    ),
                ],
                AsyncIconButton(
                  tooltip: 'เปิดไฟล์ด้วยโปรแกรมของเครื่อง',
                  icon: Icons.open_in_new,
                  onPressed: () async {
                    final error = await FileOpener.open(file.path);
                    if (error != null) state.setMessage(error);
                  },
                ),
                IconButton(
                  tooltip: 'ปิด preview',
                  onPressed: state.clearSelection,
                  icon: Icon(Icons.close, size: d.iconSm),
                ),
              ],
            ),
          ),
          Expanded(
            child: scanned == null
                ? const EmptyState(
                    icon: Icons.error_outline,
                    title: 'ไม่พบไฟล์นี้ในเครื่องแล้ว',
                  )
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
