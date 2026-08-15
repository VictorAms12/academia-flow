import 'package:flutter/material.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';
import 'widgets/motion.dart';

class AcademiaFlowApp extends StatelessWidget {
  const AcademiaFlowApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          return MaterialApp(
            title: 'Academia Flow',
            debugShowCheckedModeBanner: false,
            themeMode: state.isDark ? ThemeMode.dark : ThemeMode.light,
            themeAnimationDuration: MotionSpec.normal,
            themeAnimationCurve: MotionSpec.curve,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: state.onboardingComplete
                ? const AppShell()
                : const OnboardingScreen(),
          );
        },
      ),
    );
  }
}
