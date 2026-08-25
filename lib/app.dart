import 'dart:async';

import 'package:flutter/material.dart';
import 'data/app_database.dart';
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
  late final AppLifecycleListener _lifecycleListener;
  bool _refreshingBackgroundAttendance = false;

  @override
  void initState() {
    super.initState();
    _captureRootState();
    widget.state.addListener(_handleStateChange);
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(_refreshAfterBackgroundAttendance()),
    );
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
    _lifecycleListener.dispose();
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

  Future<void> _refreshAfterBackgroundAttendance() async {
    if (_refreshingBackgroundAttendance) return;
    _refreshingBackgroundAttendance = true;
    final database = AppDatabase.instance;
    try {
      final marker = await database.getSetting('background_attendance_refresh');
      if (marker == null || marker.trim().isEmpty) return;

      // O callback da notificação altera o SQLite sem acordar a interface.
      // Ao voltar ao app, recarregamos somente quando existe esse marcador.
      await widget.state.reloadAll(notify: false);
      await widget.state.updateRoutineSettings();
      await database.setSetting('background_attendance_refresh', '');
    } catch (_) {
      // Se a recarga falhar, preserva o marcador para tentar novamente no
      // próximo resume em vez de deixar o estado visual desatualizado.
    } finally {
      _refreshingBackgroundAttendance = false;
    }
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
