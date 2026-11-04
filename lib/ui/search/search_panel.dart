import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../../domain/models.dart';
import '../widgets/common.dart';

/// แผงซ้าย — หัวข้อหน้า · ช่องคำค้น · ปุ่มค้นหา · ขอบเขตที่ค้น · ชนิดไฟล์ · สถานะ index
class SearchPanel extends StatefulWidget {
  const SearchPanel({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  late final TextEditingController _controller = TextEditingController(
    text: context.read<AppState>().query,
  );
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
    final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: 'เลือกโฟลเดอร์ที่จะค้น');
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
    final isProject = state.mode == SearchMode.project && state.currentProject != null;
    // คำค้นอาจถูกตั้งจากที่อื่น (กดไฟล์ล่าสุดเพื่อค้นซ้ำ) → ให้ช่องกรอกตามไปด้วย
    // ทำหลังเฟรมวาดเสร็จ เพราะแก้ controller กลางการ build จะไปสั่ง rebuild ซ้อน
    if (state.query != _controller.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.text != state.query) _controller.text = state.query;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: d.fontTitle + 2,
            fontWeight: FontWeight.w700,
            color: AppColors.textStrong,
            letterSpacing: -0.3,
          ),
        ),
        if (widget.subtitle != null) ...[
          SizedBox(height: d.gap - 6),
          Text(
            widget.subtitle!,
            style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted, height: 1.4),
          ),
        ],
        SizedBox(height: d.gapLg),

        // ── คำค้น + ปุ่มค้นวงกลมในช่อง ──
        TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: state.setQuery,
          onSubmitted: (_) => state.canSearch ? state.runSearch() : null,
          decoration: InputDecoration(
            hintText: 'คำหรือประโยคที่จะค้น',
            contentPadding: EdgeInsets.symmetric(horizontal: d.gapLg, vertical: 14),
            prefixIcon: Icon(Icons.search, size: d.iconSm, color: AppColors.textMuted),
            prefixIconConstraints: BoxConstraints(minWidth: d.gapLg * 2, minHeight: d.circleBtn),
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
                : Icon(Icons.bolt_outlined, size: d.iconSm),
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
        const _SectionLabel(text: 'ขอบเขตที่ค้น'),
        SizedBox(height: d.gap),
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
                label: const Text('โฟลเดอร์', maxLines: 1, overflow: TextOverflow.ellipsis),
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
                label: const Text('ไฟล์', maxLines: 1, overflow: TextOverflow.ellipsis),
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

        // ── ชนิดไฟล์ที่จะค้น (ค่าเดียวกับหน้าตั้งค่า) ──
        SizedBox(height: d.gap),
        const _SectionLabel(text: 'ชนิดไฟล์'),
        SizedBox(height: d.gap - 4),
        Wrap(
          spacing: d.gap - 4,
          runSpacing: d.gap - 4,
          children: [
            for (final kind in FileKind.values)
              _KindChip(
                kind: kind,
                selected: state.settings.enabledKinds.contains(kind),
                onTap: () {
                  final next = {...state.settings.enabledKinds};
                  if (!next.remove(kind)) next.add(kind);
                  // ต้องเหลืออย่างน้อย 1 ชนิด ไม่งั้นค้นอะไรไม่ได้เลย
                  if (next.isEmpty) return;
                  state.updateSettings(state.settings.copyWith(enabledKinds: next));
                },
              ),
          ],
        ),

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
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: d.fontSm,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 0.4,
      ),
    );
  }
}

/// checkbox ชนิดไฟล์แบบ pill — สีตามชนิดไฟล์
class _KindChip extends StatelessWidget {
  const _KindChip({required this.kind, required this.selected, required this.onTap});

  final FileKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final color = colorOfKind(kind);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          padding: EdgeInsets.symmetric(horizontal: d.gap, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.10) : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(d.radiusPill),
            border: Border.all(
              color: selected ? color.withValues(alpha: 0.5) : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected ? Icons.check_box : Icons.check_box_outline_blank,
                size: d.iconSm,
                color: selected ? color : AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                kind.label,
                style: TextStyle(
                  fontSize: d.fontSm,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.textStrong : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
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
                final matched =
                    state.currentProject?.roots.where((r) => r.path == path).toList() ?? const [];
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
