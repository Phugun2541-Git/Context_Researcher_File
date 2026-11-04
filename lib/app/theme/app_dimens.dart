import 'package:flutter/widgets.dart';

/// token ขนาดที่อิงความกว้าง/สูงจอ — ห้าม fix px ที่ call site
class D {
  D._(this.w, this.h);

  factory D.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return D._(size.width, size.height);
  }

  final double w;
  final double h;

  /// responsive width: p = สัดส่วนของความกว้างจอ (1.0 = 1%)
  double rw(double p) => w * p / 100;
  double rh(double p) => h * p / 100;

  bool get isNarrow => w < 1000;

  double get gap => rw(0.6).clamp(6, 12);
  double get gapLg => rw(1.4).clamp(12, 24);
  double get pagePad => rw(2.0).clamp(16, 40);
  double get radius => 12;
  double get radiusLg => 20;

  /// มุมโค้งเต็มใบ — ปุ่ม/ช่องกรอก/ป้าย ใช้ทรง pill ทั้งแอป
  double get radiusPill => 999;

  /// ด้านของปุ่มไอคอนทรงกลม
  double get circleBtn => rw(2.4).clamp(34, 44);

  double get fontSm => rw(0.72).clamp(11, 13);
  double get fontBody => rw(0.82).clamp(12.5, 15);
  double get fontTitle => rw(1.05).clamp(16, 21);
  double get fontDisplay => rw(1.6).clamp(22, 32);

  double get iconSm => rw(0.95).clamp(14, 18);
  double get icon => rw(1.2).clamp(18, 24);

  double get fieldH => rh(5.5).clamp(38, 48);
  double get sidePanelW => rw(26).clamp(300, 420);
}
