import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// โลโก้ของแอป — หน้ากระดาษซ้อนกับแว่นขยาย (ค้นหาในเอกสาร)
///
/// วาดด้วย CustomPainter เพื่อให้คมทุกขนาดและเปลี่ยนสีตามธีมอัตโนมัติ
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 36, this.showPlate = true});

  final double size;

  /// true = มีพื้นสี accent ทรงสี่เหลี่ยมมนรองหลัง (ใช้เป็นไอคอนแอป)
  final bool showPlate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(
          plate: showPlate ? AppColors.accent : null,
          mark: showPlate ? AppColors.onAccent : AppColors.accent,
        ),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.plate, required this.mark});

  final Color? plate;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    if (plate != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(s * 0.26)),
        Paint()..color = plate!,
      );
    }

    final stroke = Paint()
      ..color = mark
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.066
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Offset p(double x, double y) => Offset(s * x, s * y);

    // กรอบหน้ากระดาษ + มุมพับขวาบน (สัดส่วนเดียวกับไอคอนแอป)
    final page = Path()
      ..moveTo(s * 0.58, s * 0.15)
      ..lineTo(s * 0.27, s * 0.15)
      ..lineTo(s * 0.27, s * 0.85)
      ..lineTo(s * 0.75, s * 0.85)
      ..lineTo(s * 0.75, s * 0.32)
      ..close();
    canvas.drawPath(page, stroke);
    canvas.drawLine(p(0.58, 0.15), p(0.58, 0.32), stroke);
    canvas.drawLine(p(0.58, 0.32), p(0.75, 0.32), stroke);

    // บรรทัดข้อความ
    canvas.drawLine(p(0.36, 0.30), p(0.50, 0.30), stroke);
    canvas.drawLine(p(0.36, 0.40), p(0.56, 0.40), stroke);

    // แว่นขยาย
    canvas.drawCircle(p(0.495, 0.625), s * 0.125, stroke);
    canvas.drawLine(p(0.585, 0.715), p(0.655, 0.785), stroke);
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.plate != plate || old.mark != mark;
}
