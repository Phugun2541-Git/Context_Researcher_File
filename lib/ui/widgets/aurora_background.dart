import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/motion.dart';

/// พื้นหลังไล่สีนุ่ม ๆ ที่ค่อย ๆ ขยับ — ดึงสีจากธีมที่ใช้อยู่ จึงเปลี่ยนตามธีมเอง
///
/// ใช้ความโปร่งต่ำมาก (ไม่เกิน ~12%) เพื่อไม่แย่งสายตาจากเนื้อหา
/// ปิดเอฟเฟกต์เคลื่อนไหวในหน้าตั้งค่า = วาดภาพนิ่งเฟรมเดียว ไม่กิน CPU
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({super.key, required this.child, this.intensity = 1.0});

  final Widget child;

  /// ตัวคูณความเข้มของแสง (หน้าที่มีเนื้อหาหนาแน่นใช้ค่าต่ำ)
  final double intensity;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(AuroraBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  /// หยุดวนภาพเมื่อผู้ใช้ปิดเอฟเฟกต์ในแอป หรือตั้งค่าลดการเคลื่อนไหวไว้ที่ระบบ
  void _syncAnimation() {
    final off = Motion.reduced || MediaQuery.disableAnimationsOf(context);
    if (off && _c.isAnimating) {
      _c.stop();
    } else if (!off && !_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _AuroraPainter(
                  t: _c.value,
                  intensity: widget.intensity,
                  base: AppColors.scaffoldBg,
                  accent: AppColors.accent,
                  secondary: AppColors.kindExcel,
                  tertiary: AppColors.kindWord,
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({
    required this.t,
    required this.intensity,
    required this.base,
    required this.accent,
    required this.secondary,
    required this.tertiary,
  });

  final double t;
  final double intensity;
  final Color base;
  final Color accent;
  final Color secondary;
  final Color tertiary;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = base);

    void blob(Color color, double cx, double cy, double radius, double alpha) {
      final center = Offset(size.width * cx, size.height * cy);
      final r = size.shortestSide * radius;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha * intensity),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }

    // จุดกำเนิดแสงเคลื่อนเป็นวงรีช้า ๆ คนละเฟส ทำให้พื้นหลังไม่ซ้ำรอบชัดเจน
    final a = t * 2 * math.pi;
    blob(accent, 0.18 + 0.05 * math.cos(a), 0.12 + 0.04 * math.sin(a), 0.75, 0.13);
    blob(tertiary, 0.88 + 0.04 * math.sin(a * 0.8), 0.22 + 0.05 * math.cos(a * 0.7), 0.55, 0.09);
    blob(secondary, 0.72 + 0.06 * math.cos(a * 0.6), 0.92 + 0.03 * math.sin(a * 1.1), 0.6, 0.07);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.base != base || old.accent != accent || old.intensity != intensity;
}
