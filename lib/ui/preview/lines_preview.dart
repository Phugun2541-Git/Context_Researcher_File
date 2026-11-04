import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../domain/models.dart';
import '../../services/file_scanner.dart';
import '../../services/indexer.dart';
import '../../services/match_util.dart';
import '../widgets/common.dart';

/// preview แบบรายบรรทัดสำหรับ Excel / Word / TXT-CSV
///
/// 1 แถว = 1 chunk (cell / ย่อหน้า / บรรทัด) ความสูงคงที่ → กด chip แล้วเลื่อนไปตรงจุดได้แม่น
/// Excel: แสดงเฉพาะ sheet ของจุดที่เลือก (ไม่ render ทั้ง workbook)
class LinesPreview extends StatefulWidget {
  const LinesPreview({
    super.key,
    required this.file,
    required this.query,
    this.target,
  });

  final ScannedFile file;
  final String query;
  final Locator? target;

  @override
  State<LinesPreview> createState() => _LinesPreviewState();
}

class _LinesPreviewState extends State<LinesPreview> {
  final _scroll = ScrollController();
  late Future<ExtractResult> _future = extractFile(widget.file);
  String? _pendingTargetLabel;

  @override
  void initState() {
    super.initState();
    _pendingTargetLabel = widget.target?.label;
  }

  @override
  void didUpdateWidget(LinesPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _future = extractFile(widget.file);
    }
    if (oldWidget.target?.label != widget.target?.label) {
      _pendingTargetLabel = widget.target?.label;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// chunk ที่จะแสดง — Excel จำกัดเฉพาะ sheet ที่เลือก
  List<Chunk> _visibleChunks(ExtractResult result) {
    final sheet = widget.target?.sheet;
    if (widget.file.kind != FileKind.xlsx || sheet == null) return result.chunks;
    return result.chunks.where((c) => c.locator.sheet == sheet).toList();
  }

  void _scrollToTarget(List<Chunk> chunks, double extent) {
    final label = _pendingTargetLabel;
    if (label == null || !_scroll.hasClients) return;
    final index = chunks.indexWhere((c) => c.locator.label == label);
    if (index < 0) return;
    _pendingTargetLabel = null;
    final max = _scroll.position.maxScrollExtent;
    // วางแถวเป้าหมายไว้ราว 1/3 จากขอบบน ให้เห็น context รอบ ๆ
    final offset = (index * extent - _scroll.position.viewportDimension / 3)
        .clamp(0.0, max);
    _scroll.animateTo(
      offset,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final rowHeight = (d.fontBody * 2.1).clamp(26.0, 36.0);

    return FutureBuilder<ExtractResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        final result = snapshot.data;
        if (result == null || result.status != FileStatus.ok) {
          return EmptyState(
            icon: Icons.warning_amber_rounded,
            title: 'แสดงเนื้อหาไฟล์นี้ไม่ได้',
            detail: result?.note,
          );
        }
        final chunks = _visibleChunks(result);
        if (chunks.isEmpty) {
          return const EmptyState(
            icon: Icons.notes_outlined,
            title: 'ไม่มีข้อความในไฟล์นี้',
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToTarget(chunks, rowHeight);
        });

        return ListView.builder(
          controller: _scroll,
          itemExtent: rowHeight,
          itemCount: chunks.length,
          itemBuilder: (context, i) {
            final chunk = chunks[i];
            final isTarget = widget.target?.label == chunk.locator.label;
            final occurrences = findOccurrences(chunk.text, widget.query);
            return Container(
              color: isTarget ? AppColors.accentSurface : null,
              padding: EdgeInsets.symmetric(horizontal: d.gap),
              child: Row(
                children: [
                  SizedBox(
                    width: d.rw(5).clamp(56, 92),
                    child: Text(
                      chunk.locator.label.replaceFirst('บรรทัด ', ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: d.fontSm,
                        color: isTarget ? AppColors.accent : AppColors.textMuted,
                        fontWeight: isTarget ? FontWeight.w700 : FontWeight.w400,
                        fontFeatures: const [],
                      ),
                    ),
                  ),
                  Expanded(
                    child: occurrences.isEmpty
                        ? Text(
                            chunk.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: d.fontBody,
                              color: AppColors.textBody,
                            ),
                          )
                        : HighlightedText(
                            text: chunk.text,
                            start: occurrences.first,
                            length: widget.query.length,
                            maxLines: 1,
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
