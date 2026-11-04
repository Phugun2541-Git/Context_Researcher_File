import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';

/// preview PDF + highlight คำค้นด้วย PdfTextSearcher ของ pdfrx
///
/// เลือก chip หน้าไหน → เลื่อนไปหน้านั้นและไฮไลต์ทุกคำที่ตรงในเอกสาร
class PdfPreview extends StatefulWidget {
  const PdfPreview({
    super.key,
    required this.path,
    required this.query,
    this.page,
  });

  final String path;
  final String query;
  final int? page;

  @override
  State<PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<PdfPreview> {
  final _controller = PdfViewerController();
  late final PdfTextSearcher _searcher = PdfTextSearcher(_controller)
    ..addListener(_onSearchUpdate);
  bool _ready = false;

  void _onSearchUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _searcher.removeListener(_onSearchUpdate);
    _searcher.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PdfPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_ready) return;
    if (oldWidget.query != widget.query) {
      _startSearch();
    }
    if (oldWidget.page != widget.page && widget.page != null) {
      _controller.goToPage(pageNumber: widget.page!);
    }
  }

  void _startSearch() {
    if (widget.query.trim().isEmpty) return;
    _searcher.startTextSearch(widget.query.trim(), searchImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    return Column(
      children: [
        Expanded(
          child: PdfViewer.file(
            widget.path,
            key: ValueKey(widget.path),
            controller: _controller,
            initialPageNumber: widget.page ?? 1,
            params: PdfViewerParams(
              backgroundColor: AppColors.surfaceMuted,
              pagePaintCallbacks: [_searcher.pageTextMatchPaintCallback],
              onViewerReady: (document, controller) async {
                _ready = true;
                _startSearch();
                if (widget.page != null) {
                  await controller.goToPage(pageNumber: widget.page!);
                }
              },
            ),
          ),
        ),
        // แถบควบคุมคำที่พบในเอกสาร (เลื่อนไปจุดถัดไป/ก่อนหน้า)
        Container(
          padding: EdgeInsets.symmetric(horizontal: d.gap, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _searcher.isSearching
                      ? 'กำลังไฮไลต์…'
                      : _searcher.matches.isEmpty
                          ? 'ไม่มีคำที่ไฮไลต์ในไฟล์นี้'
                          : 'จุดที่ ${(_searcher.currentIndex ?? 0) + 1} / ${_searcher.matches.length}',
                  style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
                ),
              ),
              IconButton(
                tooltip: 'จุดก่อนหน้า',
                onPressed: _searcher.matches.isEmpty ? null : _searcher.goToPrevMatch,
                icon: Icon(Icons.keyboard_arrow_up, size: d.icon),
              ),
              IconButton(
                tooltip: 'จุดถัดไป',
                onPressed: _searcher.matches.isEmpty ? null : _searcher.goToNextMatch,
                icon: Icon(Icons.keyboard_arrow_down, size: d.icon),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
