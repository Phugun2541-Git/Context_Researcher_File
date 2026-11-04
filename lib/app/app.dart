import 'package:flutter/material.dart';

import '../ui/projects/projects_screen.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Context Researcher',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const ProjectsScreen(),
    );
  }
}
