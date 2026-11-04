import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_state.dart';
import 'search_workspace.dart';

/// หน้าค้นหาของโปรเจคที่เลือกจากเมนูซ้าย
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return SearchWorkspace(
      title: state.currentProject?.name ?? 'โปรเจค',
      subtitle: 'ค้นในโฟลเดอร์ที่ผูกไว้กับโปรเจคนี้',
    );
  }
}
