import 'package:flutter/widgets.dart';

/// ค่า animation กลาง — ใช้ที่เดียวทั้งแอปเพื่อให้จังหวะเท่ากัน
class Motion {
  /// ปิดเอฟเฟกต์ทั้งแอปจากหน้าตั้งค่า (คืน Duration.zero ให้ทุกจุดพร้อมกัน)
  static bool reduced = false;

  static Duration get fast =>
      reduced ? Duration.zero : const Duration(milliseconds: 150);
  static Duration get base =>
      reduced ? Duration.zero : const Duration(milliseconds: 240);
  static Duration get slow =>
      reduced ? Duration.zero : const Duration(milliseconds: 420);

  static const curve = Curves.easeOutCubic;
  static const curveIn = Curves.easeInCubic;

  /// หน่วงแบบขั้นบันไดสำหรับ list (index ยิ่งมาก ยิ่งเข้าช้า) — cap กันรายการยาวรอนาน
  static Duration stagger(int index) => reduced
      ? Duration.zero
      : Duration(milliseconds: (index.clamp(0, 12)) * 35);
}

/// fade + เลื่อนขึ้นเล็กน้อย ใช้ห่อ item ใน list ผลค้นหา
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offsetY = 12,
  });

  final Widget child;
  final Duration delay;
  final double offsetY;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Motion.base,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(parent: _c, curve: Motion.curve);
    return FadeTransition(
      opacity: a,
      child: AnimatedBuilder(
        animation: a,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offsetY * (1 - a.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
