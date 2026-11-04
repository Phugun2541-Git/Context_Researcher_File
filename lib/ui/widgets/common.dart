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

/// ปุ่มไอคอนทรงกลมมีขอบบาง — ใช้กับปุ่มเสริมที่หัวหน้าจอ (ย้อนกลับ · ตั้งค่า · ปิด)
class CircleIconButton extends StatefulWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.color,
    this.size,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  /// true = พื้น accent ตัวอักษรขาว (ปุ่มหลัก) · false = พื้นขาวขอบบาง
  final bool filled;
  final Color? color;
  final double? size;

  @override
  State<CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<CircleIconButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final side = widget.size ?? d.circleBtn;
    final fg = widget.filled ? AppColors.onAccent : (widget.color ?? AppColors.textBody);
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: Motion.fast,
            curve: Motion.curve,
            width: side,
            height: side,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.filled
                  ? AppColors.accent
                  : (_hover ? AppColors.accentSurface : AppColors.surface),
              border: widget.filled ? null : Border.all(color: AppColors.border),
            ),
            child: Icon(widget.icon, size: d.iconSm, color: fg),
          ),
        ),
      ),
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
    // ใช้ Text.rich ไม่ใช่ RichText เพราะ RichText ไม่สืบทอด DefaultTextStyle
    // จะทำให้ข้อความส่วนนี้ได้ฟอนต์คนละตัวกับทั้งแอป
    return Text.rich(
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      TextSpan(style: style, children: [
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(d.radiusPill),
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

/// สีประจำชนิดไฟล์ — ใช้ทั้งป้าย ไอคอน และขอบการ์ด เพื่อให้กวาดตาแยกประเภทได้เร็ว
Color colorOfKind(FileKind kind) => switch (kind) {
      FileKind.pdf => AppColors.kindPdf,
      FileKind.xlsx => AppColors.kindExcel,
      FileKind.docx => AppColors.kindWord,
      FileKind.text => AppColors.kindText,
    };

IconData iconOfKind(FileKind kind) => switch (kind) {
      FileKind.pdf => Icons.picture_as_pdf_outlined,
      FileKind.xlsx => Icons.table_chart_outlined,
      FileKind.docx => Icons.article_outlined,
      FileKind.text => Icons.notes_outlined,
    };

/// ปุ่มไอคอนที่ยิงงาน async — กดแล้วจะปิดตัวเองและขึ้น spinner จนกว่างานจะจบ
/// (กันกดรัว ๆ แล้วสั่งเปิดไฟล์/ค้นซ้ำซ้อน)
class AsyncIconButton extends StatefulWidget {
  const AsyncIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final Future<void> Function() onPressed;
  final Color? color;

  @override
  State<AsyncIconButton> createState() => _AsyncIconButtonState();
}

class _AsyncIconButtonState extends State<AsyncIconButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: _busy ? null : _run,
      icon: AnimatedSwitcher(
        duration: Motion.fast,
        child: _busy
            ? SizedBox(
                key: const ValueKey('busy'),
                width: d.iconSm,
                height: d.iconSm,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AppColors.textMuted),
                ),
              )
            : Icon(
                widget.icon,
                key: ValueKey(widget.icon),
                size: d.iconSm,
                color: widget.color,
              ),
      ),
    );
  }
}

/// ไอคอนชนิดไฟล์ทรงสี่เหลี่ยมมุมมน พื้นสีประจำชนิด ตัวอักษรขาว (X = Excel · W = Word)
class FileKindTile extends StatelessWidget {
  const FileKindTile({super.key, required this.kind, this.size});

  final FileKind kind;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final side = size ?? d.icon * 1.7;
    final color = colorOfKind(kind);
    final letter = switch (kind) {
      FileKind.xlsx => 'X',
      FileKind.docx => 'W',
      FileKind.pdf => 'P',
      FileKind.text => 'T',
    };
    return Container(
      width: side,
      height: side,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(side * 0.28),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: side * 0.52,
          height: 1.1,
          fontWeight: FontWeight.w700,
          color: AppColors.onAccent,
        ),
      ),
    );
  }
}

/// วันเวลาแบบสั้นสำหรับการ์ดผลค้นหา — วันนี้/เมื่อวาน แล้วตามด้วยเวลา
String shortDateLabel(int mtimeMs) {
  if (mtimeMs <= 0) return '';
  final t = DateTime.fromMillisecondsSinceEpoch(mtimeMs);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(t.year, t.month, t.day);
  final hhmm =
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  final diff = today.difference(that).inDays;
  if (diff == 0) return 'วันนี้ $hhmm';
  if (diff == 1) return 'เมื่อวาน $hhmm';
  if (that.year == now.year) return '${t.day}/${t.month} $hhmm';
  return '${t.day}/${t.month}/${t.year}';
}
