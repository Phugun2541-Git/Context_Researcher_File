import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../../domain/models.dart';

/// การ์ดโปรเจคบนหน้าแรก — hover ยกขึ้นเล็กน้อย
class ProjectCard extends StatefulWidget {
  const ProjectCard({
    super.key,
    required this.project,
    required this.onOpen,
    required this.onDelete,
  });

  final Project project;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final p = widget.project;
    final indexed = p.lastIndexedAt;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onOpen,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.curve,
          transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
          padding: EdgeInsets.all(d.gapLg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(d.radiusLg),
            border: Border.all(
              color: _hover ? AppColors.accent : AppColors.border,
            ),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: AppColors.textStrong.withValues(alpha: 0.07),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_rounded,
                      size: d.icon, color: AppColors.accent),
                  SizedBox(width: d.gap),
                  Expanded(
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: d.fontTitle,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textStrong,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    duration: Motion.fast,
                    opacity: _hover ? 1 : 0,
                    child: IconButton(
                      tooltip: 'ลบโปรเจค',
                      onPressed: widget.onDelete,
                      icon: Icon(Icons.delete_outline,
                          size: d.iconSm, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${p.roots.length} ตำแหน่งที่ผูกไว้ · ${p.fileCount} ไฟล์ใน index',
                style: TextStyle(fontSize: d.fontSm, color: AppColors.textBody),
              ),
              const SizedBox(height: 2),
              Text(
                indexed == null
                    ? 'ยังไม่เคย index'
                    : 'index ล่าสุด ${DateFormat('d MMM yy HH:mm').format(indexed)}',
                style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
