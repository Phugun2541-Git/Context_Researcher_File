import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_info.dart';
import '../../app/app_state.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../../data/db.dart';
import '../../domain/models.dart';
import '../../services/file_opener.dart';
import '../widgets/aurora_background.dart';
import '../widgets/common.dart';

/// หน้าตั้งค่า — ธีม · การแสดงผล · ขอบเขตการค้น · ข้อมูลที่เก็บไว้
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = context.watch<AppState>();
    final settings = state.settings;

    return Scaffold(
      body: AuroraBackground(
        intensity: 0.55,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(d.pagePad * 0.8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'กลับ',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(Icons.arrow_back, size: d.icon),
                    ),
                    SizedBox(width: d.gap - 4),
                    Text(
                      'ตั้งค่า',
                      style: TextStyle(
                        fontSize: d.fontTitle,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textStrong,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: d.gapLg),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: d.rw(60).clamp(560, 860)),
                      child: ListView(
                        children: [
                          _Section(
                            title: 'ธีมสี',
                            subtitle: 'เปลี่ยนแล้วมีผลทันทีทั้งแอป',
                            child: Wrap(
                              spacing: d.gap,
                              runSpacing: d.gap,
                              children: [
                                for (final option in kThemeOptions)
                                  _ThemeSwatch(
                                    option: option,
                                    selected: settings.themeId == option.id,
                                    onTap: () =>
                                        state.updateSettings(settings.copyWith(themeId: option.id)),
                                  ),
                              ],
                            ),
                          ),
                          _Section(
                            title: 'การแสดงผล',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ขนาดตัวอักษร',
                                  style: TextStyle(fontSize: d.fontBody, color: AppColors.textBody),
                                ),
                                SizedBox(height: d.gap),
                                Row(
                                  children: [
                                    for (final item in const [
                                      (0.9, 'เล็ก'),
                                      (1.0, 'ปกติ'),
                                      (1.15, 'ใหญ่'),
                                    ])
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: HitChip(
                                          label: item.$2,
                                          selected: settings.fontScale == item.$1,
                                          onTap: () => state.updateSettings(
                                            settings.copyWith(fontScale: item.$1),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: d.gapLg),
                                // ไม่ใช้ SwitchListTile เพราะอยู่ใน card ที่มีพื้นหลังเอง
                                // (Flutter เตือนว่า ink/สีพื้นของ ListTile จะมองไม่เห็น)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'ปิดเอฟเฟกต์เคลื่อนไหว',
                                            style: TextStyle(fontSize: d.fontBody),
                                          ),
                                          Text(
                                            'เหมาะกับเครื่องช้า หรือไม่ชอบภาพเคลื่อนไหว',
                                            style: TextStyle(
                                              fontSize: d.fontSm,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: settings.reduceMotion,
                                      onChanged: (v) =>
                                          state.updateSettings(settings.copyWith(reduceMotion: v)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          _Section(
                            title: 'ขอบเขตการค้น',
                            subtitle: 'ตัดชนิดไฟล์ที่ไม่ใช้ออก ทำให้ index เร็วขึ้น',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: d.gap,
                                  runSpacing: d.gap,
                                  children: [
                                    for (final kind in FileKind.values)
                                      _KindToggle(
                                        kind: kind,
                                        selected: settings.enabledKinds.contains(kind),
                                        onTap: () {
                                          final next = {...settings.enabledKinds};
                                          if (!next.remove(kind)) next.add(kind);
                                          // ต้องเหลืออย่างน้อย 1 ชนิด ไม่งั้นค้นอะไรไม่ได้เลย
                                          if (next.isEmpty) return;
                                          state.updateSettings(
                                            settings.copyWith(enabledKinds: next),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                                SizedBox(height: d.gapLg),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'ข้ามไฟล์ที่ใหญ่กว่า',
                                        style: TextStyle(
                                          fontSize: d.fontBody,
                                          color: AppColors.textBody,
                                        ),
                                      ),
                                    ),
                                    DropdownButton<int>(
                                      value: settings.maxFileSizeMb,
                                      underline: const SizedBox.shrink(),
                                      items: const [16, 32, 64, 128, 256]
                                          .map(
                                            (mb) =>
                                                DropdownMenuItem(value: mb, child: Text('$mb MB')),
                                          )
                                          .toList(),
                                      onChanged: (mb) => mb == null
                                          ? null
                                          : state.updateSettings(
                                              settings.copyWith(maxFileSizeMb: mb),
                                            ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const _Section(
                            title: 'ข้อมูลที่เก็บไว้',
                            subtitle: 'index เก็บข้อความของไฟล์ไว้ในเครื่องนี้เท่านั้น',
                            child: _StorageInfo(),
                          ),
                          _Section(
                            title: 'เกี่ยวกับ',
                            child: Text(
                              '$kAppName $kAppVersion',
                              style: TextStyle(fontSize: d.fontBody, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: d.gapLg),
      child: PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: d.fontBody + 1,
                fontWeight: FontWeight.w700,
                color: AppColors.textStrong,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
              ),
            ],
            SizedBox(height: d.gapLg * 0.8),
            child,
          ],
        ),
      ),
    );
  }
}

/// การ์ดตัวอย่างธีม — โชว์สีพื้น/สี accent/สีตัวอักษรของธีมนั้นจริง ๆ
class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.option, required this.selected, required this.onTap});

  final ThemeOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final p = option.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(d.radius),
      child: AnimatedContainer(
        duration: Motion.fast,
        width: d.rw(12).clamp(132, 176),
        padding: EdgeInsets.all(d.gap),
        decoration: BoxDecoration(
          color: p.scaffoldBg,
          borderRadius: BorderRadius.circular(d.radius),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ตัวอย่างย่อของหน้าจอจริง (การ์ด + ปุ่ม) อ่านออกง่ายกว่าจุดสีเปล่า ๆ
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(d.gap * 0.7),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(d.radius * 0.7),
                border: Border.all(color: p.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(p.textStrong, 42, 5),
                  const SizedBox(height: 4),
                  _bar(p.textMuted, 58, 4),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _bar(p.accent, 30, 10, radius: 5),
                      const SizedBox(width: 4),
                      _bar(p.accentSurface, 18, 10, radius: 5),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: d.gap * 0.8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    option.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: d.fontSm,
                      fontWeight: FontWeight.w600,
                      color: p.textStrong,
                    ),
                  ),
                ),
                if (selected) Icon(Icons.check_circle, size: d.iconSm, color: AppColors.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _bar(Color color, double width, double height, {double radius = 2}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
  );
}

class _KindToggle extends StatelessWidget {
  const _KindToggle({required this.kind, required this.selected, required this.onTap});

  final FileKind kind;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final color = colorOfKind(kind);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(d.radius),
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: EdgeInsets.symmetric(horizontal: d.gap, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.10) : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(d.radius),
          border: Border.all(color: selected ? color.withValues(alpha: 0.5) : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_box : Icons.check_box_outline_blank,
              size: d.iconSm,
              color: selected ? color : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Icon(iconOfKind(kind), size: d.iconSm, color: color),
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
    );
  }
}

/// ที่อยู่ไฟล์ index + ขนาด + ปุ่มล้าง
class _StorageInfo extends StatefulWidget {
  const _StorageInfo();

  @override
  State<_StorageInfo> createState() => _StorageInfoState();
}

class _StorageInfoState extends State<_StorageInfo> {
  String _size = '-';

  @override
  void initState() {
    super.initState();
    _refreshSize();
  }

  void _refreshSize() {
    try {
      final bytes = File(AppDb.instance.path).lengthSync();
      setState(() => _size = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB');
    } catch (_) {
      setState(() => _size = '-');
    }
  }

  Future<void> _clearIndex() async {
    final state = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ล้าง index ทั้งหมด?'),
        content: const Text(
          'ลบข้อความที่อ่านเก็บไว้ของทุกโปรเจค · โปรเจคและโฟลเดอร์ที่ผูกไว้ยังอยู่ '
          'ครั้งหน้าที่ค้นระบบจะอ่านไฟล์ใหม่ทั้งหมด',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ล้าง'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    state.indexRepo.clearAllIndex();
    state.loadProjects();
    _refreshSize();
  }

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final path = AppDb.instance.path;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          path,
          style: TextStyle(fontSize: d.fontSm, color: AppColors.textBody),
        ),
        const SizedBox(height: 4),
        Text(
          'ขนาดไฟล์ index: $_size',
          style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
        ),
        SizedBox(height: d.gapLg * 0.8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => FileOpener.revealInExplorer(path),
              icon: Icon(Icons.folder_open_outlined, size: d.iconSm),
              label: const Text('เปิดโฟลเดอร์'),
            ),
            SizedBox(width: d.gap),
            OutlinedButton.icon(
              onPressed: _clearIndex,
              icon: Icon(Icons.delete_sweep_outlined, size: d.iconSm, color: AppColors.danger),
              label: Text('ล้าง index', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      ],
    );
  }
}
