import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../widgets/common.dart';

/// แผงซ้าย — ช่องคำค้น · ปุ่มค้นหา · ขอบเขตที่ค้น (โฟลเดอร์/ไฟล์) · สถานะ index
class SearchPanel extends StatefulWidget {
  const SearchPanel({super.key});

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  late final TextEditingController _controller =
      TextEditingController(text: context.read<AppState>().query);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final state = context.read<AppState>();
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'เลือกโฟลเดอร์ที่จะค้น',
    );
    if (dir != null) state.addRoots([dir]);
  }

  Future<void> _pickFiles() async {
    final state = context.read<AppState>();
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      dialogTitle: 'เลือกไฟล์ที่จะค้น',
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'xlsx', 'xlsm', 'docx', 'txt', 'csv', 'tsv', 'md', 'log'],
    );
    final paths = picked?.files.map((f) => f.path).whereType<String>().toList();
    if (paths != null && paths.isNotEmpty) state.addRoots(paths);
  }

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    final isProject = state.mode == SearchMode.project;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── หัวแผง ──
        Row(
          children: [
            CircleIconButton(
              tooltip: 'กลับหน้าโปรเจค',
              icon: Icons.arrow_back,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            SizedBox(width: d.gap - 4),
            Expanded(
              child: Text(
                isProject
                    ? (state.currentProject?.name ?? 'โปรเจค')
                    : 'ค้นหาแบบไม่ผูกโปรเจค',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: d.fontTitle,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textStrong,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: d.gapLg),

        // ── คำค้น + ปุ่มค้นหา ──
        TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: state.setQuery,
          onSubmitted: (_) => state.canSearch ? state.runSearch() : null,
          decoration: InputDecoration(
            hintText: 'คำหรือประโยคที่จะค้น',
            contentPadding: EdgeInsets.symmetric(horizontal: d.gapLg, vertical: 14),
            // ปุ่มค้นวงกลมอยู่ในช่องเลย (แนบขอบขวา) จึงต้องกันพื้นที่ให้พอ
            suffixIconConstraints: BoxConstraints(minHeight: d.circleBtn, minWidth: d.circleBtn),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_controller.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        state.setQuery('');
                      },
                      child: Padding(
                        padding: EdgeInsets.only(right: d.gap - 4),
                        child: Icon(Icons.close, size: d.iconSm, color: AppColors.textMuted),
                      ),
                    ),
                  _SearchCircleButton(busy: state.searching || state.indexing),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: d.gap),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: state.canSearch ? state.runSearch : null,
            icon: state.searching || state.indexing
                ? SizedBox(
                    width: d.iconSm,
                    height: d.iconSm,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(AppColors.onAccent),
                    ),
                  )
                : Icon(Icons.travel_explore, size: d.iconSm),
            label: Text(state.searching || state.indexing ? 'กำลังค้น…' : 'ค้นหา'),
          ),
        ),
        if (state.activeRoots.isEmpty) ...[
          SizedBox(height: d.gap),
          Text(
            'เลือกโฟลเดอร์หรือไฟล์ก่อน',
            style: TextStyle(fontSize: d.fontSm, color: AppColors.warning),
          ),
        ],

        SizedBox(height: d.gapLg),
        Divider(height: 1, color: AppColors.border),
        SizedBox(height: d.gapLg),

        // ── ขอบเขตที่ค้น ──
        Text(
          'ขอบเขตที่ค้น',
          style: TextStyle(
            fontSize: d.fontSm,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: d.gap),
        // ปุ่มคู่นี้อยู่ในแผงแคบ → บีบ padding และให้ป้ายย่อได้ กันล้นตอนย่อหน้าต่าง
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFolder,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(Icons.folder_outlined, size: d.iconSm),
                label: const Text(
                  'โฟลเดอร์',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            SizedBox(width: d.gap),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickFiles,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  visualDensity: VisualDensity.compact,
                ),
                icon: Icon(Icons.description_outlined, size: d.iconSm),
                label: const Text(
                  'ไฟล์',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: d.gap),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.base,
            child: state.activeRoots.isEmpty
                ? Align(
                    key: const ValueKey('no-root'),
                    alignment: Alignment.topLeft,
                    child: Text(
                      'ยังไม่ได้เลือกขอบเขต',
                      style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
                    ),
                  )
                : ListView(
                    key: ValueKey('roots-${state.activeRoots.length}'),
                    padding: EdgeInsets.zero,
                    children: [
                      for (var i = 0; i < state.activeRoots.length; i++)
                        FadeSlideIn(
                          delay: Motion.stagger(i),
                          offsetY: 6,
                          child: _RootRow(path: state.activeRoots[i]),
                        ),
                    ],
                  ),
          ),
        ),

        // ── index / progress / message ──
        if (isProject) ...[
          SizedBox(height: d.gap),
          Text(
            '${state.currentProject?.fileCount ?? 0} ไฟล์ใน index',
            style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
          ),
        ],
        if (state.progress != null) ...[
          SizedBox(height: d.gap),
          ScanProgressBar(
            progress: state.progress!,
            label: state.indexing ? 'กำลัง index' : 'กำลังอ่านไฟล์',
          ),
        ],
        if (state.message != null) ...[
          SizedBox(height: d.gap),
          Text(
            state.message!,
            style: TextStyle(fontSize: d.fontSm, color: AppColors.danger),
          ),
        ],
      ],
    );
  }
}

/// ปุ่มค้นวงกลมที่ฝังอยู่ในช่องคำค้น — ปิดตัวเองตอนยังค้นไม่ได้ และขึ้น spinner ระหว่างค้น
class _SearchCircleButton extends StatelessWidget {
  const _SearchCircleButton({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    final enabled = state.canSearch;
    final side = d.circleBtn * 0.82;
    return GestureDetector(
      onTap: enabled ? state.runSearch : null,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled || busy ? AppColors.accent : AppColors.border,
          ),
          child: busy
              ? Padding(
                  padding: EdgeInsets.all(side * 0.27),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.onAccent),
                  ),
                )
              : Icon(Icons.search, size: d.iconSm, color: AppColors.onAccent),
        ),
      ),
    );
  }
}

class _RootRow extends StatelessWidget {
  const _RootRow({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.read<AppState>();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: d.gap, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(d.radiusPill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: path,
              child: Text(
                path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: d.fontSm, color: AppColors.textBody),
              ),
            ),
          ),
          InkWell(
            onTap: () {
              if (state.mode == SearchMode.project) {
                final matched = state.currentProject?.roots
                        .where((r) => r.path == path)
                        .toList() ??
                    const [];
                if (matched.isNotEmpty) state.removeRoot(matched.first);
              } else {
                state.removeAdHocRoot(path);
              }
            },
            child: Icon(Icons.close, size: d.iconSm, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
