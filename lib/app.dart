import 'package:flutter/material.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';

class AcademiaFlowApp extends StatefulWidget {
  const AcademiaFlowApp({super.key});

  @override
  State<AcademiaFlowApp> createState() => _AcademiaFlowAppState();
}

class _AcademiaFlowAppState extends State<AcademiaFlowApp> {
  late final AppState appState;

  @override
  void initState() {
    super.initState();
    appState = AppState();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: appState,
      child: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          return MaterialApp(
            title: 'Academia Flow',
            debugShowCheckedModeBanner: false,
            themeMode: appState.isDark ? ThemeMode.dark : ThemeMode.light,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
