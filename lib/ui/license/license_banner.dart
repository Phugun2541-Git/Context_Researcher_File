import 'package:flutter/material.dart';

import '../../app/app_info.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import 'license_controller.dart';

/// แถบเตือนใกล้หมดอายุ — ไม่มีใบอนุญาตใน context (เช่นในเทส) หรือยังไม่ใกล้หมด = ไม่แสดงอะไร
class LicenseBanner extends StatelessWidget {
  const LicenseBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final state = LicenseController.maybeOf(context)?.state;
    if (state == null || !state.expiringSoon) return const SizedBox.shrink();
    final days = state.daysLeft ?? 0;
    return Container(
      margin: EdgeInsets.only(bottom: d.gapLg),
      padding: EdgeInsets.symmetric(horizontal: d.gapLg, vertical: d.gap),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(d.radiusPill),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, size: d.iconSm, color: AppColors.warning),
          SizedBox(width: d.gap),
          Expanded(
            child: Text(
              days <= 0
                  ? 'ใบอนุญาตหมดอายุวันนี้ · ติดต่อ $kContactEmail เพื่อต่ออายุ'
                  : 'ใบอนุญาตเหลืออีก $days วัน · ติดต่อ $kContactEmail เพื่อต่ออายุ',
              style: TextStyle(fontSize: d.fontSm, color: AppColors.textBody),
            ),
          ),
        ],
      ),
    );
  }
}
