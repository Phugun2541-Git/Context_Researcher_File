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
                  // กล่องไอคอนสีอ่อน ช่วยให้การ์ดมีจุดนำสายตาโดยไม่ต้องใช้สีเต็มใบ
                  Container(
                    width: d.icon * 1.7,
                    height: d.icon * 1.7,
                    decoration: BoxDecoration(
                      color: AppColors.accentSurface,
                      borderRadius: BorderRadius.circular(d.radius),
                    ),
                    child: Icon(
                      Icons.folder_rounded,
                      size: d.icon,
                      color: AppColors.accent,
                    ),
                  ),
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
                      icon: Icon(
                        Icons.delete_outline,
                        size: d.iconSm,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: d.gap),

              // โฟลเดอร์ที่ผูกไว้ — ให้เห็นตั้งแต่หน้าแรกว่าโปรเจคนี้ชี้ไปที่ไหน
              for (final root in p.roots.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(
                        root.isFile
                            ? Icons.description_outlined
                            : Icons.folder_outlined,
                        size: d.fontSm,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          root.path,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: d.fontSm,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (p.roots.length > 2)
                Text(
                  '+ อีก ${p.roots.length - 2} ตำแหน่ง',
                  style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
                ),
              if (p.roots.isEmpty)
                Text(
                  'ยังไม่ได้ผูกโฟลเดอร์',
                  style: TextStyle(fontSize: d.fontSm, color: AppColors.warning),
                ),

              const Spacer(),
              Divider(height: d.gapLg, color: AppColors.border),
              Row(
                children: [
                  Icon(Icons.description_outlined,
                      size: d.fontSm, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${p.fileCount} ไฟล์',
                    style: TextStyle(fontSize: d.fontSm, color: AppColors.textBody),
                  ),
                  const Spacer(),
                  Text(
                    indexed == null
                        ? 'ยังไม่เคย index'
                        : DateFormat('d MMM yy HH:mm').format(indexed),
                    style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
