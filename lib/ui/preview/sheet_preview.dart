import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../../domain/models.dart';
import '../../services/extractors/xlsx_extractor.dart';
import '../../services/file_scanner.dart';
import '../../services/indexer.dart';
import '../../services/match_util.dart';
import '../widgets/common.dart';

/// preview Excel เป็นตารางจริง — หัวคอลัมน์ A B C · เลขแถวด้านซ้าย · ไฮไลต์ช่องที่พบคำ
///
/// เลื่อนแนวตั้งด้วย ListView ที่ itemExtent คงที่ เพื่อ jump ไปแถวเป้าหมายได้แม่น
/// และห่อด้วย scroll แนวนอนอันเดียวให้หัวตารางกับเนื้อตารางเลื่อนตรงกัน
class SheetPreview extends StatefulWidget {
  const SheetPreview({
    super.key,
    required this.file,
    required this.query,
    this.target,
  });

  final ScannedFile file;
  final String query;
  final Locator? target;

  @override
  State<SheetPreview> createState() => _SheetPreviewState();
}

class _SheetPreviewState extends State<SheetPreview> {
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  late Future<ExtractResult> _future = extractFile(widget.file);
  String? _activeSheet;
  String? _pendingTargetCell;

  @override
  void initState() {
    super.initState();
    _activeSheet = widget.target?.sheet;
    _pendingTargetCell = widget.target?.cell;
  }

  @override
  void didUpdateWidget(SheetPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) {
      _future = extractFile(widget.file);
      _activeSheet = widget.target?.sheet;
    }
    if (oldWidget.target?.label != widget.target?.label) {
      if (widget.target?.sheet != null) _activeSheet = widget.target!.sheet;
      _pendingTargetCell = widget.target?.cell;
    }
  }

  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  void _scrollToTarget(_SheetGrid grid, double rowHeight, double cellWidth) {
    final cell = _pendingTargetCell;
    if (cell == null) return;
    final rowIndex = grid.rows.indexOf(rowOfRef(cell));
    final colIndex = grid.columns.indexOf(columnOfRef(cell));
    if (rowIndex < 0) return;
    _pendingTargetCell = null;

    if (_vertical.hasClients) {
      final offset = (rowIndex * rowHeight - _vertical.position.viewportDimension / 3)
          .clamp(0.0, _vertical.position.maxScrollExtent);
      _vertical.animateTo(offset, duration: Motion.base, curve: Motion.curve);
    }
    if (colIndex >= 0 && _horizontal.hasClients) {
      final offset = (colIndex * cellWidth - _horizontal.position.viewportDimension / 3)
          .clamp(0.0, _horizontal.position.maxScrollExtent);
      _horizontal.animateTo(offset, duration: Motion.base, curve: Motion.curve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final rowHeight = (d.fontBody * 2.3).clamp(28.0, 40.0);
    final cellWidth = d.rw(11).clamp(120.0, 200.0);
    final rowHeadWidth = d.rw(4).clamp(44.0, 64.0);

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
            title: 'เปิดไฟล์นี้ไม่ได้',
            detail: result?.note,
          );
        }

        final sheets = <String>[];
        for (final chunk in result.chunks) {
          final name = chunk.locator.sheet;
          if (name != null && !sheets.contains(name)) sheets.add(name);
        }
        if (sheets.isEmpty) {
          return const EmptyState(
            icon: Icons.table_chart_outlined,
            title: 'ไม่มีข้อมูลในไฟล์นี้',
          );
        }
        final active = sheets.contains(_activeSheet) ? _activeSheet! : sheets.first;
        final grid = _SheetGrid.from(result.chunks, active);
        final totalWidth = rowHeadWidth + grid.columns.length * cellWidth;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToTarget(grid, rowHeight, cellWidth);
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sheets.length > 1) _sheetTabs(sheets, active, d),
            Expanded(
              child: Scrollbar(
                controller: _horizontal,
                child: SingleChildScrollView(
                  controller: _horizontal,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: totalWidth,
                    child: Column(
                      children: [
                        _headerRow(grid, d, rowHeadWidth, cellWidth, rowHeight),
                        Expanded(
                          child: ListView.builder(
                            controller: _vertical,
                            itemExtent: rowHeight,
                            itemCount: grid.rows.length,
                            itemBuilder: (context, i) => _dataRow(
                              grid,
                              i,
                              d,
                              rowHeadWidth,
                              cellWidth,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sheetTabs(List<String> sheets, String active, D d) {
    return SizedBox(
      // เผื่อความสูงให้ chip ไม่โดนตัดขอบล่าง
      height: d.fieldH * 1.05,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: d.gap, vertical: 4),
        itemCount: sheets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, i) => HitChip(
          label: sheets[i],
          selected: sheets[i] == active,
          onTap: () => setState(() => _activeSheet = sheets[i]),
        ),
      ),
    );
  }

  Widget _headerRow(
    _SheetGrid grid,
    D d,
    double rowHeadWidth,
    double cellWidth,
    double rowHeight,
  ) {
    final targetColumn =
        widget.target?.cell == null ? null : columnOfRef(widget.target!.cell!);
    return Container(
      height: rowHeight * 0.85,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          SizedBox(width: rowHeadWidth),
          for (final column in grid.columns)
            Container(
              width: cellWidth,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: column == targetColumn
                    ? AppColors.accentSurface
                    : Colors.transparent,
                border: Border(left: BorderSide(color: AppColors.border)),
              ),
              child: Text(
                column,
                style: TextStyle(
                  fontSize: d.fontSm,
                  fontWeight: FontWeight.w700,
                  color: column == targetColumn
                      ? AppColors.accent
                      : AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dataRow(
    _SheetGrid grid,
    int index,
    D d,
    double rowHeadWidth,
    double cellWidth,
  ) {
    final rowNumber = grid.rows[index];
    final targetCell = widget.target?.cell;
    final isTargetRow = targetCell != null && rowOfRef(targetCell) == rowNumber;

    return Row(
      children: [
        Container(
          width: rowHeadWidth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isTargetRow ? AppColors.accentSurface : AppColors.surfaceMuted,
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          child: Text(
            '$rowNumber',
            style: TextStyle(
              fontSize: d.fontSm,
              color: isTargetRow ? AppColors.accent : AppColors.textMuted,
              fontWeight: isTargetRow ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        for (final column in grid.columns)
          _cell(
            grid: grid,
            column: column,
            rowNumber: rowNumber,
            width: cellWidth,
            d: d,
            isTarget: targetCell == '$column$rowNumber',
          ),
      ],
    );
  }

  Widget _cell({
    required _SheetGrid grid,
    required String column,
    required int rowNumber,
    required double width,
    required D d,
    required bool isTarget,
  }) {
    final text = grid.cells['$column$rowNumber'] ?? '';
    final occurrences =
        widget.query.isEmpty ? const <int>[] : findOccurrences(text, widget.query);
    return Container(
      width: width,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isTarget ? AppColors.accentSurface : null,
        border: Border(
          left: BorderSide(
            color: isTarget ? AppColors.accent : AppColors.border,
            width: isTarget ? 1.4 : 1,
          ),
          bottom: BorderSide(
            color: isTarget ? AppColors.accent : AppColors.border,
            width: isTarget ? 1.4 : 1,
          ),
        ),
      ),
      child: occurrences.isEmpty
          ? Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: d.fontSm, color: AppColors.textBody),
            )
          : HighlightedText(
              text: text,
              start: occurrences.first,
              length: widget.query.length,
              maxLines: 1,
              fontSize: d.fontSm,
            ),
    );
  }
}

/// ตารางของ sheet เดียว: รายการแถวที่มีข้อมูล · คอลัมน์ที่มีข้อมูล · map ref -> ข้อความ
class _SheetGrid {
  _SheetGrid({required this.rows, required this.columns, required this.cells});

  final List<int> rows;
  final List<String> columns;
  final Map<String, String> cells;

  static _SheetGrid from(List<Chunk> chunks, String sheet) {
    final cells = <String, String>{};
    final rows = <int>{};
    final columnIndexes = <int>{};
    for (final chunk in chunks) {
      if (chunk.locator.sheet != sheet) continue;
      final ref = chunk.locator.cell;
      if (ref == null) continue;
      cells[ref] = chunk.text;
      rows.add(rowOfRef(ref));
      columnIndexes.add(columnIndexOfRef(ref));
    }
    final sortedRows = rows.toList()..sort();
    final sortedColumns = columnIndexes.toList()..sort();
    return _SheetGrid(
      rows: sortedRows,
      columns: sortedColumns.map(columnLetter).toList(),
      cells: cells,
    );
  }
}
