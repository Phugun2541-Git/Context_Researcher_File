import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../../domain/models.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../widgets/common.dart';
import 'project_card.dart';

/// หน้าแรก — การ์ดโปรเจคที่เคยผูกโฟลเดอร์ไว้ + ทางเข้าค้นหาแบบไม่ผูกโปรเจค
class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    final projects = state.projects;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(d.pagePad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: d.gap,
                  runSpacing: d.gap,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Context Researcher',
                          style: TextStyle(
                            fontSize: d.fontDisplay,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textStrong,
                            letterSpacing: -0.4,
                          ),
                        ),
                        SizedBox(height: d.gap - 4),
                        Text(
                          'ค้นคำในเอกสาร PDF · Excel · Word · CSV/TXT ตามโฟลเดอร์ที่เลือก',
                          style: TextStyle(
                            fontSize: d.fontBody,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'ตั้งค่า',
                          onPressed: () => Navigator.of(context)
                              .push(_route(const SettingsScreen())),
                          icon: Icon(Icons.settings_outlined, size: d.icon),
                        ),
                        SizedBox(width: d.gap - 4),
                        OutlinedButton.icon(
                          onPressed: () {
                            state.startAdHoc();
                            Navigator.of(context).push(_route(const SearchScreen()));
                          },
                          icon: Icon(Icons.bolt_outlined, size: d.iconSm),
                          label: const Text('ค้นแบบไม่ผูกโปรเจค'),
                        ),
                        SizedBox(width: d.gap),
                        FilledButton.icon(
                          onPressed: () => _createProject(context),
                          icon: Icon(Icons.add, size: d.iconSm),
                          label: const Text('โปรเจคใหม่'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: d.gapLg * 1.4),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.base,
                  child: projects.isEmpty
                      ? EmptyState(
                          key: const ValueKey('empty'),
                          icon: Icons.folder_open_outlined,
                          title: 'ยังไม่มีโปรเจค',
                          detail: 'ผูกโฟลเดอร์งานไว้ในโปรเจค '
                              'ครั้งหน้าเปิดมาค้นได้เลย',
                          action: FilledButton.icon(
                            onPressed: () => _createProject(context),
                            icon: const Icon(Icons.add),
                            label: const Text('สร้างโปรเจคแรก'),
                          ),
                        )
                      : GridView.builder(
                          key: ValueKey('grid-${projects.length}'),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: d.rw(26).clamp(260, 360),
                            mainAxisExtent: d.rh(22).clamp(150, 190),
                            crossAxisSpacing: d.gapLg,
                            mainAxisSpacing: d.gapLg,
                          ),
                          itemCount: projects.length,
                          itemBuilder: (context, i) => FadeSlideIn(
                            delay: Motion.stagger(i),
                            child: ProjectCard(
                              project: projects[i],
                              onOpen: () {
                                state.openProject(projects[i]);
                                Navigator.of(context)
                                    .push(_route(const SearchScreen()));
                              },
                              onDelete: () => _confirmDelete(context, projects[i]),
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Route<void> _route(Widget child) => PageRouteBuilder<void>(
        transitionDuration: Motion.base,
        reverseTransitionDuration: Motion.fast,
        pageBuilder: (_, __, ___) => child,
        transitionsBuilder: (_, animation, __, child) {
          final curved = CurvedAnimation(parent: animation, curve: Motion.curve);
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.02), end: Offset.zero)
                  .animate(curved),
              child: child,
            ),
          );
        },
      );

  Future<void> _createProject(BuildContext context) async {
    final state = context.read<AppState>();
    final result = await showDialog<_NewProjectResult>(
      context: context,
      builder: (_) => const _NewProjectDialog(),
    );
    if (result == null || result.name.trim().isEmpty) return;
    final id = state.createProject(result.name);
    final created = state.projects.firstWhere((p) => p.id == id);
    state.openProject(created);
    if (result.roots.isNotEmpty) state.addRoots(result.roots);
    if (!context.mounted) return;
    Navigator.of(context).push(_route(const SearchScreen()));
  }

  Future<void> _confirmDelete(BuildContext context, Project project) async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบโปรเจคนี้?'),
        content: Text(
          'ลบ "${project.name}" และ index ที่เก็บไว้ · ไฟล์เอกสารจริงไม่ถูกลบ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok == true) state.deleteProject(project.id);
  }
}

class _NewProjectResult {
  const _NewProjectResult(this.name, this.roots);

  final String name;
  final List<String> roots;
}

class _NewProjectDialog extends StatefulWidget {
  const _NewProjectDialog();

  @override
  State<_NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<_NewProjectDialog> {
  final _controller = TextEditingController();
  final _roots = <String>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    final dir = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'เลือกโฟลเดอร์ของโปรเจค',
    );
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
              decoration: const InputDecoration(
                hintText: 'ชื่อโปรเจค เช่น RMA',
              ),
              onSubmitted: (_) => Navigator.pop(
                context,
                _NewProjectResult(_controller.text, _roots),
              ),
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
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _NewProjectResult(_controller.text, _roots),
          ),
          child: const Text('สร้าง'),
        ),
      ],
    );
  }
}
