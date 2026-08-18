import 'package:flutter/material.dart';
import 'screens/onboarding_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/app_shell.dart';
import 'widgets/motion.dart';

class AcademiaFlowApp extends StatefulWidget {
  const AcademiaFlowApp({super.key, required this.state});

  final AppState state;

  @override
  State<AcademiaFlowApp> createState() => _AcademiaFlowAppState();
}

class _AcademiaFlowAppState extends State<AcademiaFlowApp> {
  late bool _dark;
  late bool _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _captureRootState();
    widget.state.addListener(_handleStateChange);
  }

  @override
  void didUpdateWidget(covariant AcademiaFlowApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.state, widget.state)) return;
    oldWidget.state.removeListener(_handleStateChange);
    _captureRootState();
    widget.state.addListener(_handleStateChange);
  }

  @override
  void dispose() {
    widget.state.removeListener(_handleStateChange);
    super.dispose();
  }

  void _captureRootState() {
    _dark = widget.state.isDark;
    _onboardingComplete = widget.state.onboardingComplete;
  }

  void _handleStateChange() {
    final dark = widget.state.isDark;
    final onboarding = widget.state.onboardingComplete;
    if (dark == _dark && onboarding == _onboardingComplete) return;
    if (!mounted) return;
    setState(() {
      _dark = dark;
      _onboardingComplete = onboarding;
    });
  }

  @override
  Widget build(BuildContext context) {
    // AppStateScope continua notificando somente os widgets que dependem do
    // estado acadêmico. O MaterialApp/Navigator não é mais reconstruído por
    // toda alteração de tarefa, nota, presença ou sincronização.
    return AppStateScope(
      notifier: widget.state,
      child: MaterialApp(
        title: 'Academia Flow',
        debugShowCheckedModeBanner: false,
        themeMode: _dark ? ThemeMode.dark : ThemeMode.light,
        themeAnimationDuration: MotionSpec.normal,
        themeAnimationCurve: MotionSpec.curve,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        home: _onboardingComplete ? const AppShell() : const OnboardingScreen(),
      ),
    );
  }
}
