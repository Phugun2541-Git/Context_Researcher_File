import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../data/db.dart';
import '../../services/license/license_service.dart';
import '../../services/license/license_store.dart';
import '../../services/license/machine_id.dart';
import 'license_controller.dart';

/// ประตูหน้าแอป — ผ่านก็เข้าแอปปกติ ไม่ผ่านก็เห็นแต่หน้า activate
class LicenseGate extends StatefulWidget {
  const LicenseGate({super.key, required this.child, required this.lockedBuilder, this.service});

  final Widget child;

  /// หน้าที่แสดงตอนใช้งานไม่ได้ (แยกเป็น builder เพื่อให้เทสใส่หน้าปลอมได้)
  final Widget Function(BuildContext context, LicenseState state, Future<void> Function(String))
  lockedBuilder;

  /// null = สร้างของจริง (DPAPI + registry) ตอน initState
  final LicenseService? service;

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> {
  late final LicenseController _controller = LicenseController(
    widget.service ??
        LicenseService(
          // อยู่โฟลเดอร์เดียวกับ index.db แต่คนละไฟล์ และเข้ารหัสด้วย DPAPI
          store: DpapiLicenseStore(p.join(p.dirname(AppDb.instance.path), 'license.bin')),
          machineIdProvider: MachineId.current,
        ),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _activate(String path) async {
    final error = _controller.activate(path);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider<LicenseController>.value(
    value: _controller,
    child: Consumer<LicenseController>(
      builder: (context, controller, child) =>
          controller.state.allowed ? child! : widget.lockedBuilder(context, controller.state, _activate),
      child: widget.child,
    ),
  );
}
