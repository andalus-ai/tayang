import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'presentation/pages/editor_page.dart';

class TayangApp extends StatelessWidget {
  const TayangApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Tayang',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const EditorPage(),
      );
}
