import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../../services/license/license_service.dart';

/// ถือสถานะใบอนุญาตของทั้งแอป — ใส่ใบใหม่แล้วทุกหน้าที่ฟังอยู่อัปเดตตาม
class LicenseController extends ChangeNotifier {
  LicenseController(this._service) : _state = _service.check();

  final LicenseService _service;
  LicenseState _state;

  LicenseState get state => _state;

  /// คืนข้อความ error ถ้าใบนี้ใช้ไม่ได้ · null = สำเร็จ
  String? activate(String path) {
    final next = _service.activateFromFile(path);
    _state = next;
    notifyListeners();
    return next.allowed ? null : (next.message ?? 'ใบอนุญาตนี้ใช้ไม่ได้');
  }

  /// หน้าจอที่เรนเดอร์เดี่ยว ๆ ในเทสจะไม่มี controller — ต้องยอมให้ไม่มีค่าได้
  static LicenseController? maybeOf(BuildContext context, {bool listen = true}) {
    try {
      return listen ? context.watch<LicenseController>() : context.read<LicenseController>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}
