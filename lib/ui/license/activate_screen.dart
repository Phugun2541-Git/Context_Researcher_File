import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_info.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_dimens.dart';
import '../../services/license/license_service.dart';
import '../../services/license/machine_id.dart';
import '../widgets/aurora_background.dart';
import '../widgets/common.dart';

/// หน้าล็อก — แสดงเมื่อยังไม่ได้ใส่ใบอนุญาต หรือใบอนุญาตใช้ไม่ได้แล้ว
class ActivateScreen extends StatelessWidget {
  const ActivateScreen({super.key, required this.state, required this.onPick, this.busy = false});

  final LicenseState state;

  /// คืนข้อความ error ถ้าใส่ไม่สำเร็จ · null = ผ่าน
  final Future<void> Function(String path) onPick;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final d = D.of(context);
    final machine = state.machineId;
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(d.pagePad),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: d.rw(40).clamp(420, 560)),
                child: PanelCard(
                  padding: EdgeInsets.all(d.gapLg * 1.4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _title(state.status),
                        style: TextStyle(
                          fontSize: d.fontTitle,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textStrong,
                        ),
                      ),
                      SizedBox(height: d.gap - 2),
                      Text(
                        _detail(state),
                        style: TextStyle(
                          fontSize: d.fontBody,
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                      if (machine != null) ...[
                        SizedBox(height: d.gapLg),
                        Text(
                          'รหัสเครื่องนี้',
                          style: TextStyle(
                            fontSize: d.fontSm,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                        SizedBox(height: d.gap - 4),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: d.gapLg,
                            vertical: d.gap,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(d.radius),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: SelectableText(
                                  MachineId.format(machine),
                                  style: TextStyle(
                                    fontSize: d.fontBody,
                                    color: AppColors.textBody,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              AsyncIconButton(
                                tooltip: 'คัดลอกรหัสเครื่อง',
                                icon: Icons.copy_all_outlined,
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: MachineId.format(machine)),
                                  );
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('คัดลอกรหัสเครื่องแล้ว'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: d.gapLg),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: busy ? null : () => _pick(context),
                          icon: busy
                              ? SizedBox(
                                  width: d.iconSm,
                                  height: d.iconSm,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(AppColors.onAccent),
                                  ),
                                )
                              : Icon(Icons.vpn_key_outlined, size: d.iconSm),
                          label: const Text(
                            'เลือกไฟล์ใบอนุญาต (.lic)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(height: d.gapLg),
                      Divider(height: 1, color: AppColors.border),
                      SizedBox(height: d.gap),
                      Row(
                        children: [
                          Icon(Icons.mail_outline, size: d.iconSm, color: AppColors.textMuted),
                          SizedBox(width: d.gap - 2),
                          Expanded(
                            child: SelectableText(
                              'ขอใบอนุญาต/ต่ออายุ: $kContactEmail',
                              style: TextStyle(fontSize: d.fontSm, color: AppColors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'เลือกไฟล์ใบอนุญาต',
      type: FileType.custom,
      allowedExtensions: const ['lic'],
    );
    final path = picked?.files.single.path;
    if (path != null) await onPick(path);
  }

  static String _title(LicenseStatus status) => switch (status) {
    LicenseStatus.none => 'ใส่ใบอนุญาตก่อนใช้งาน',
    LicenseStatus.expired => 'ใบอนุญาตหมดอายุแล้ว',
    LicenseStatus.machineMismatch => 'ใบอนุญาตนี้ไม่ใช่ของเครื่องนี้',
    LicenseStatus.invalid => 'ไฟล์ใบอนุญาตใช้ไม่ได้',
    LicenseStatus.clockTampered => 'เวลาของเครื่องผิดปกติ',
    LicenseStatus.machineUnreadable => 'อ่านรหัสเครื่องไม่ได้',
    LicenseStatus.notConfigured => 'โปรแกรมยังตั้งค่าไม่ครบ',
    LicenseStatus.active => 'ใช้งานได้',
  };

  static String _detail(LicenseState state) => switch (state.status) {
    LicenseStatus.none =>
      'ส่งรหัสเครื่องด้านล่างให้ผู้ขาย เพื่อรับไฟล์ .lic ของเครื่องนี้ '
          'แล้วกดเลือกไฟล์ที่ได้มา',
    LicenseStatus.expired =>
      'ขอไฟล์ .lic ใบใหม่แล้วเลือกทับใบเดิมได้เลย ข้อมูลและ index ที่เก็บไว้ยังอยู่ครบ',
    LicenseStatus.machineMismatch =>
      'ใบอนุญาต 1 ใบใช้ได้ 1 เครื่อง · ส่งรหัสเครื่องนี้ไปขอใบใหม่',
    LicenseStatus.invalid =>
      '${state.message ?? 'ไฟล์เสียหาย'} · ลองขอไฟล์ใบอนุญาตใหม่จากผู้ขาย',
    LicenseStatus.clockTampered =>
      'เวลาของเครื่องย้อนหลังกว่าการใช้งานครั้งล่าสุด '
          'ตั้งวันเวลาของ Windows ให้ถูกต้องแล้วเปิดโปรแกรมใหม่',
    LicenseStatus.machineUnreadable =>
      '${state.message ?? ''} · ติดต่อผู้ขายพร้อมแจ้งข้อความนี้',
    LicenseStatus.notConfigured =>
      'ยังไม่ได้ฝังกุญแจตรวจใบอนุญาตในโปรแกรมรุ่นนี้ (ติดต่อผู้พัฒนา)',
    LicenseStatus.active => '',
  };
}
