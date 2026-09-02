import 'package:flutter/material.dart';
import '../models/models.dart';
import '../screens/analytics_screen.dart';
import '../screens/global_search_screen.dart';
import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/routine_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/subjects_screen.dart';
import '../screens/tasks_screen.dart';
import '../services/notification_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'motion.dart';
import 'v22_actions.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static const destinations = [
    (Icons.today_rounded, 'Hoje'),
    (Icons.auto_stories_rounded, 'Matérias'),
    (Icons.task_alt_rounded, 'Atividades'),
    (Icons.analytics_rounded, 'Desempenho'),
    (Icons.school_rounded, 'Rotina'),
  ];

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final NotificationService _notifications = NotificationService.instance;
  bool _handlingNotificationNavigation = false;

  @override
  void initState() {
    super.initState();
    _notifications.navigationPayload.addListener(_onNavigationPayloadChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeNavigationPayload());
  }

  @override
  void dispose() {
    _notifications.navigationPayload.removeListener(_onNavigationPayloadChanged);
    super.dispose();
  }

  void _onNavigationPayloadChanged() {
    if (_notifications.navigationPayload.value == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeNavigationPayload());
  }

  Future<void> _consumeNavigationPayload() async {
    if (!mounted || _handlingNotificationNavigation) return;
    final payload = _notifications.takeNavigationPayload();
    if (payload == null || payload.isEmpty) return;

    _handlingNotificationNavigation = true;
    try {
      final state = AppStateScope.of(context);
      if (payload.startsWith('task:')) {
        final id = int.tryParse(payload.split(':').last);
        AcademicTask? task;
        for (final candidate in state.tasks) {
          if (candidate.id == id) {
            task = candidate;
            break;
          }
        }
        state.setIndex(2);
        if (task != null && mounted) {
          await showTaskEditor(context, state, task: task);
        }
        return;
      }

      if (payload.startsWith('session:')) {
        state.setIndex(4);
      }
    } finally {
      _handlingNotificationNavigation = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    const screens = [
      HomeScreen(),
      SubjectsScreen(),
      TasksScreen(),
      AnalyticsScreen(),
      RoutineScreen(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (desktop) _DesktopNav(state: state),
                Expanded(
                  child: Column(
                    children: [
                      _TopBar(desktop: desktop, state: state),
                      Expanded(
                        child: IndexedStack(
                          index: state.currentIndex,
                          children: [
                            for (var i = 0; i < screens.length; i++)
                              TickerMode(
                                enabled: state.currentIndex == i,
                                child: screens[i],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: MotionEntrance(
            delay: const Duration(milliseconds: 120),
            offset: const Offset(0, .12),
            child: FloatingActionButton.extended(
              onPressed: () => showQuickAddSheet(context, state),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Adicionar'),
            ),
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: state.currentIndex,
                  onDestinationSelected: state.setIndex,
                  destinations: [for (final d in AppShell.destinations) NavigationDestination(icon: Icon(d.$1), label: d.$2)],
                ),
        );
      },
    );
  }
}

class _DesktopNav extends StatelessWidget {
  const _DesktopNav({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 244,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0B2832) : Colors.white,
        border: Border(right: BorderSide(color: dark ? Colors.white.withValues(alpha: .06) : Colors.black.withValues(alpha: .06))),
      ),
      child: Column(
        children: [
          const Row(children: [
            _Logo(),
            SizedBox(width: 11),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Academia Flow', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              Text('Academic OS', style: TextStyle(fontSize: 11)),
            ])),
          ]),
          const SizedBox(height: 28),
          for (var i = 0; i < AppShell.destinations.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _MotionNavItem(
                selected: state.currentIndex == i,
                icon: AppShell.destinations[i].$1,
                label: AppShell.destinations[i].$2,
                badge: i == 2 && state.pendingCount > 0 ? state.pendingCount : i == 4 && state.pendingAttendance.isNotEmpty ? state.pendingAttendance.length : null,
                onTap: () => state.setIndex(i),
              ),
            ),
          const Divider(height: 22),
          _SecondaryNav(icon: Icons.search_rounded, label: 'Busca global', onTap: () => Navigator.push(context, motionRoute(const GlobalSearchScreen()))),
          _SecondaryNav(icon: Icons.menu_book_rounded, label: 'Biblioteca', onTap: () => Navigator.push(context, motionRoute(const LibraryScreen()))),
          const Spacer(),
          if (state.semester.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: .08), borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.gold.withValues(alpha: .16))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('SEMESTRE', style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(state.semester, style: const TextStyle(fontWeight: FontWeight.w900)),
              ]),
            ),
          Row(children: [
            CircleAvatar(radius: 18, backgroundColor: AppColors.petroleum, child: Text(_initials(state.userName), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11))),
            const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(state.userName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              Text(state.period.isEmpty ? state.course : '${state.course} • ${state.period}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10)),
            ])),
          ]),
        ],
      ),
    );
  }
}

class _MotionNavItem extends StatefulWidget {
  const _MotionNavItem({required this.selected, required this.icon, required this.label, required this.onTap, this.badge});
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;
  @override
  State<_MotionNavItem> createState() => _MotionNavItemState();
}

class _MotionNavItemState extends State<_MotionNavItem> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedContainer(
        duration: MotionSpec.fast,
        curve: MotionSpec.curve,
        transform: Matrix4.translationValues(hovered && !widget.selected ? 3 : 0, 0, 0),
        decoration: BoxDecoration(color: widget.selected ? primary.withValues(alpha: .10) : hovered ? primary.withValues(alpha: .045) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
            child: Row(children: [
              AnimatedScale(scale: widget.selected ? 1.08 : 1, duration: MotionSpec.fast, curve: MotionSpec.spring, child: Icon(widget.icon, size: 21, color: widget.selected ? primary : null)),
              const SizedBox(width: 11),
              Expanded(child: Text(widget.label, style: TextStyle(fontWeight: widget.selected ? FontWeight.w900 : FontWeight.w600))),
              if (widget.badge != null)
                Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3), decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(20)), child: Text('${widget.badge}', style: const TextStyle(color: AppColors.petroleumDark, fontSize: 10, fontWeight: FontWeight.w900))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SecondaryNav extends StatefulWidget {
  const _SecondaryNav({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  State<_SecondaryNav> createState() => _SecondaryNavState();
}

class _SecondaryNavState extends State<_SecondaryNav> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: AnimatedSlide(
          offset: hovered ? const Offset(.012, 0) : Offset.zero,
          duration: MotionSpec.fast,
          curve: MotionSpec.curve,
          child: ListTile(dense: true, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), leading: Icon(widget.icon, size: 20), title: Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), onTap: widget.onTap),
        ),
      );
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.desktop, required this.state});
  final bool desktop;
  final AppState state;
  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(desktop ? 26 : 17, 14, desktop ? 26 : 17, 7),
        child: Row(children: [
          if (!desktop) ...[const _Logo(), const SizedBox(width: 9), const Text('Academia Flow', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))] else const Spacer(),
          if (!desktop) const Spacer(),
          IconButton.filledTonal(tooltip: 'Busca global', onPressed: () => Navigator.push(context, motionRoute(const GlobalSearchScreen())), icon: const Icon(Icons.search_rounded)),
          const SizedBox(width: 6),
          IconButton.filledTonal(tooltip: 'Biblioteca', onPressed: () => Navigator.push(context, motionRoute(const LibraryScreen())), icon: const Icon(Icons.menu_book_outlined)),
          const SizedBox(width: 6),
          IconButton.filledTonal(
            tooltip: 'Tema',
            onPressed: state.toggleTheme,
            icon: AnimatedSwitcher(duration: MotionSpec.normal, transitionBuilder: (child, animation) => RotationTransition(turns: Tween<double>(begin: -.18, end: 0).animate(animation), child: FadeTransition(opacity: animation, child: child)), child: Icon(state.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded, key: ValueKey(state.isDark))),
          ),
          const SizedBox(width: 6),
          IconButton.filledTonal(tooltip: 'Configurações', onPressed: () => Navigator.push(context, motionRoute(const SettingsScreen())), icon: const Icon(Icons.settings_outlined)),
        ]),
      );
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) => Container(width: 41, height: 41, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.petroleum, Color(0xFF17697A)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.school_rounded, color: AppColors.gold, size: 22));
}

String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return 'AF';
  if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
  return '${p.first[0]}${p.last[0]}'.toUpperCase();
}
