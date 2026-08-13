import 'package:flutter/material.dart';
import '../screens/analytics_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/schedule_screen.dart';
import '../screens/subjects_screen.dart';
import '../screens/tasks_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  static const destinations = [
    (Icons.space_dashboard_rounded, 'Visão geral'),
    (Icons.auto_stories_rounded, 'Matérias'),
    (Icons.task_alt_rounded, 'Atividades'),
    (Icons.analytics_rounded, 'Desempenho'),
    (Icons.calendar_month_rounded, 'Horários'),
  ];

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final screens = const [
      DashboardScreen(),
      SubjectsScreen(),
      TasksScreen(),
      AnalyticsScreen(),
      ScheduleScreen(),
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
                      _TopBar(desktop: desktop),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween(
                                  begin: const Offset(.02, 0),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey(state.currentIndex),
                            child: screens[state.currentIndex],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: state.currentIndex,
                  onDestinationSelected: state.setIndex,
                  destinations: [
                    for (final d in destinations)
                      NavigationDestination(
                        icon: Icon(d.$1),
                        label: d.$2 == 'Visão geral' ? 'Início' : d.$2,
                      ),
                  ],
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
      width: 248,
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF0B2832) : Colors.white,
        border: Border(
          right: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: .06)
                : Colors.black.withValues(alpha: .06),
          ),
        ),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              _Logo(),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Academia Flow',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                    Text('Academic OS', style: TextStyle(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
          for (var i = 0; i < AppShell.destinations.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _NavButton(
                selected: state.currentIndex == i,
                icon: AppShell.destinations[i].$1,
                label: AppShell.destinations[i].$2,
                badge: i == 2 ? state.pendingCount : null,
                onTap: () => state.setIndex(i),
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: .18)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Semestre 2026.2',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    Text('42%',
                        style: TextStyle(
                            color: AppColors.gold, fontWeight: FontWeight.w900)),
                  ],
                ),
                SizedBox(height: 10),
                LinearProgressIndicator(
                  value: .42,
                  minHeight: 7,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                  color: AppColors.gold,
                ),
                SizedBox(height: 8),
                Text('8 semanas restantes', style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.petroleum,
                child: Text('VA',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Victor Alexandre',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                    Text('ADS • 2º período', style: TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge,
  });
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? Theme.of(context).colorScheme.primary.withValues(alpha: .10)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              Icon(icon,
                  size: 21,
                  color: selected ? Theme.of(context).colorScheme.primary : null),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
              if (badge != null && badge! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$badge',
                    style: const TextStyle(
                      color: AppColors.petroleumDark,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.desktop});
  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(desktop ? 26 : 18, 16, desktop ? 26 : 18, 8),
      child: Row(
        children: [
          if (!desktop) ...[
            const _Logo(),
            const SizedBox(width: 10),
            const Text('Academia Flow',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          ] else
            const Spacer(),
          if (!desktop) const Spacer(),
          IconButton.filledTonal(
            tooltip: 'Alternar tema',
            onPressed: state.toggleTheme,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: Icon(
                state.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                key: ValueKey(state.isDark),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Notificações',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Você tem 3 lembretes acadêmicos próximos.')),
              );
            },
            icon: const Badge(
              smallSize: 8,
              child: Icon(Icons.notifications_none_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.petroleum, Color(0xFF17697A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            color: AppColors.petroleum.withValues(alpha: .18),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.school_rounded, color: AppColors.gold, size: 23),
    );
  }
}
