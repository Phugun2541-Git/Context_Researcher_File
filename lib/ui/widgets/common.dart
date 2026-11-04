import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../app/theme/motion.dart';
import '../../domain/models.dart';

/// การ์ดพื้นขาวขอบบาง — บล็อกพื้นฐานของทุกหน้า
class PanelCard extends StatelessWidget {
  const PanelCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    return Container(
      padding: padding ?? EdgeInsets.all(d.gapLg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(d.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// ข้อความที่ระบายสีคำค้น
class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.start,
    required this.length,
    this.maxLines = 2,
    this.fontSize,
  });

  final String text;
  final int start;
  final int length;
  final int maxLines;
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final style = TextStyle(
      fontSize: fontSize ?? d.fontBody,
      color: AppColors.textBody,
      height: 1.45,
    );
    if (length <= 0 || start < 0 || start + length > text.length) {
      return Text(text, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: style);
    }
    return RichText(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: style, children: [
        TextSpan(text: text.substring(0, start)),
        TextSpan(
          text: text.substring(start, start + length),
          style: TextStyle(
            backgroundColor: AppColors.highlight,
            fontWeight: FontWeight.w600,
            color: AppColors.textStrong,
          ),
        ),
        TextSpan(text: text.substring(start + length)),
      ]),
    );
  }
}

/// chip ของจุดที่พบ เช่น "หน้า 4" / "Sheet1!B12" / "บรรทัด 88"
class HitChip extends StatefulWidget {
  const HitChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<HitChip> createState() => _HitChipState();
}

class _HitChipState extends State<HitChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final selected = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Motion.fast,
          curve: Motion.curve,
          padding: EdgeInsets.symmetric(horizontal: d.gap + 2, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent
                : (_hover ? AppColors.accentSurface : AppColors.surfaceMuted),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: d.fontSm,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.onAccent : AppColors.textBody,
            ),
          ),
        ),
      ),
    );
  }
}

/// ป้ายชนิดไฟล์
class KindBadge extends StatelessWidget {
  const KindBadge({super.key, required this.kind});

  final FileKind kind;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        kind.label,
        style: TextStyle(
          fontSize: d.fontSm - 1,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// สถานะว่าง/กำลังรอ — ข้อความบอกว่าต้องทำอะไรต่อ
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? detail;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    return Center(
      child: FadeSlideIn(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: d.icon * 2.2, color: AppColors.textMuted),
            SizedBox(height: d.gapLg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: d.fontTitle - 2,
                fontWeight: FontWeight.w600,
                color: AppColors.textStrong,
              ),
            ),
            if (detail != null) ...[
              SizedBox(height: d.gap),
              SizedBox(
                width: d.rw(30).clamp(240, 460),
                child: Text(
                  detail!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: d.fontBody, color: AppColors.textMuted),
                ),
              ),
            ],
            if (action != null) ...[SizedBox(height: d.gapLg), action!],
          ],
        ),
      ),
    );
  }
}

/// แถบความคืบหน้าแบบ minimal + ข้อความไฟล์ที่กำลังอ่าน
class ScanProgressBar extends StatelessWidget {
  const ScanProgressBar({super.key, required this.progress, this.label});

  final ScanProgress progress;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final name = progress.currentFile?.split(RegExp(r'[\\/]')).last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: progress.ratio),
            duration: Motion.base,
            curve: Motion.curve,
            builder: (context, value, _) => LinearProgressIndicator(
              value: progress.total == 0 ? null : value,
              minHeight: 4,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
        ),
        SizedBox(height: d.gap - 2),
        Text(
          '${label ?? 'กำลังอ่านไฟล์'} ${progress.done}/${progress.total}'
          '${name == null ? '' : ' · $name'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
