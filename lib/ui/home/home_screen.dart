import 'package:flutter/material.dart';

import '../search/search_workspace.dart';
import 'recent_list.dart';

/// หน้าหลัก — ค้นด่วนโดยไม่ต้องสร้างโปรเจค · ยังไม่ได้ค้นจะโชว์ไฟล์ที่เพิ่งเปิดล่าสุด
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const SearchWorkspace(
    title: 'ค้นหาในไฟล์ของคุณ',
    subtitle: 'เลือกโฟลเดอร์แล้วค้นได้เลย ไม่ต้องสร้างโปรเจค',
    emptyChild: RecentList(),
  );
}
