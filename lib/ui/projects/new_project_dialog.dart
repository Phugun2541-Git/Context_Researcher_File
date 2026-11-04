import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';

/// สร้างโปรเจคใหม่: ถามชื่อ (+ เลือกโฟลเดอร์เลยก็ได้) → สร้าง → เปิดหน้าค้นหาของโปรเจคนั้น
Future<void> createProjectFlow(BuildContext context) async {
  final state = context.read<AppState>();
  final result = await showDialog<NewProjectResult>(
    context: context,
    builder: (_) => const NewProjectDialog(),
  );
  if (result == null || result.name.trim().isEmpty) return;
  final id = state.createProject(result.name.trim());
  final created = state.projects.firstWhere((p) => p.id == id);
  state.openProject(created);
  if (result.roots.isNotEmpty) state.addRoots(result.roots);
}

class NewProjectResult {
  const NewProjectResult(this.name, this.roots);

  final String name;
  final List<String> roots;
}

class NewProjectDialog extends StatefulWidget {
  const NewProjectDialog({super.key});

  @override
  State<NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<NewProjectDialog> {
  final _controller = TextEditingController();
  final _roots = <String>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath(dialogTitle: 'เลือกโฟลเดอร์ของโปรเจค');
    if (dir != null && mounted) setState(() => _roots.add(dir));
  }

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    return AlertDialog(
      title: const Text('โปรเจคใหม่'),
      content: SizedBox(
        width: d.rw(32).clamp(320, 460),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'ชื่อโปรเจค เช่น RMA'),
              onSubmitted: (_) =>
                  Navigator.pop(context, NewProjectResult(_controller.text, _roots)),
            ),
            SizedBox(height: d.gapLg),
            OutlinedButton.icon(
              onPressed: _pickFolder,
              icon: Icon(Icons.folder_outlined, size: d.iconSm),
              label: const Text('เลือกโฟลเดอร์ (เพิ่มทีหลังได้)'),
            ),
            if (_roots.isNotEmpty) ...[
              SizedBox(height: d.gap),
              ..._roots.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    r,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('ยกเลิก')),
        FilledButton(
          onPressed: () => Navigator.pop(context, NewProjectResult(_controller.text, _roots)),
          child: const Text('สร้าง'),
        ),
      ],
    );
  }
}
