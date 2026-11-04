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
import 'pdf_preview.dart';
import 'sheet_preview.dart';

/// แผงขวา — หัวไฟล์ + เนื้อไฟล์ที่เลื่อนไปจุดที่พบให้
/// (ไม่มีแท็บรายการจุดที่พบ เพราะ chip ในการ์ดผลบอกจุดที่พบอยู่แล้ว)
class PreviewPane extends StatefulWidget {
  const PreviewPane({super.key});

  @override
  State<PreviewPane> createState() => _PreviewPaneState();
}

class _PreviewPaneState extends State<PreviewPane> {
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

          Expanded(
            child: scanned == null
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
