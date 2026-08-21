import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/v26_models.dart';
import '../state/app_state.dart';
import '../state/v26_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/routine_today_card.dart';
import '../widgets/v22_actions.dart';
import '../widgets/v26_actions.dart';
import 'attendance_review_screen.dart';
import 'grade_lab_screen.dart';
import 'notification_center_screen.dart';
import 'task_focus_screen.dart';
import 'weekly_planner_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final smart = V26Controller.instance;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    smart.initialize(AppStateScope.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    smart.bind(state);
    return AnimatedBuilder(
      animation: smart,
      builder: (context, _) {
        final prioritized = smart.prioritizedTasks(limit: 6);
        final current = state.currentSession;
        final todayStudy = smart.studyBlocksForDate(DateTime.now());
        final insights = smart.activeInsights(state);
        final overdue = state.tasks.where((task) => task.status != TaskStatus.done && _isOverdue(task.dueDate)).length;
        final firstName = state.userName.trim().isEmpty ? 'estudante' : state.userName.trim().split(RegExp(r'\s+')).first;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MotionEntrance(
                    child: _Hero(
                      state: state,
                      smart: smart,
                      firstName: firstName,
                      insightCount: insights.length,
                      todayStudyCount: todayStudy.length,
                    ),
                  ),
                  const SizedBox(height: 14),
                  MotionEntrance(delay: const Duration(milliseconds: 45), child: RoutineTodayCard(state: state)),
                  if (current != null) ...[
                    const SizedBox(height: 10),
                    _CurrentClassActions(state: state, session: current),
                  ],
                  const SizedBox(height: 14),
                  _SmartSummary(state: state, smart: smart, overdue: overdue, insightCount: insights.length),
                  const SizedBox(height: 18),
                  const SectionTitle('Ações inteligentes'),
                  const SizedBox(height: 10),
                  _QuickActions(state: state, smart: smart),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, c) {
                      final priority = _PriorityPanel(state: state, tasks: prioritized);
                      final study = _StudyPanel(state: state, smart: smart, items: todayStudy);
                      if (c.maxWidth >= 850) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 3, child: priority),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: study),
                          ],
                        );
                      }
                      return Column(children: [priority, const SizedBox(height: 12), study]);
                    },
                  ),
                  const SizedBox(height: 14),
                  _AttentionPanel(state: state, smart: smart, insights: insights.take(4).toList()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.state,
    required this.smart,
    required this.firstName,
    required this.insightCount,
    required this.todayStudyCount,
  });
  final AppState state;
  final V26Controller smart;
  final String firstName;
  final int insightCount;
  final int todayStudyCount;

  @override
  Widget build(BuildContext context) {
    final current = state.currentSession;
    final next = state.nextSession;
    final tasksToday = state.dueToday.length;
    final sessionsToday = state.sessionsToday.where((session) => session.status != AttendanceStatus.cancelled).length;
    final load = smart.dailyLoadLabel(DateTime.now());
    final contextText = current != null
        ? '${state.subjectName(current.subjectId)} está acontecendo agora.'
        : next != null && _sameDay(next.date, DateTime.now())
            ? 'Próxima aula: ${state.subjectName(next.subjectId)} às ${next.start}.'
            : insightCount > 0
                ? 'Você tem $insightCount ponto${insightCount == 1 ? '' : 's'} que merecem atenção.'
                : 'Sua rotina acadêmica está organizada para hoje.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.petroleum, Color(0xFF123A44), AppColors.petroleumDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withValues(alpha: .16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (state.semester.isNotEmpty) GoldBadge(state.semester.toUpperCase()),
              _HeroBadge('$sessionsToday AULA${sessionsToday == 1 ? '' : 'S'}'),
              _HeroBadge('$tasksToday PRAZO${tasksToday == 1 ? '' : 'S'}'),
              if (todayStudyCount > 0) _HeroBadge('$todayStudyCount ESTUDO${todayStudyCount == 1 ? '' : 'S'}'),
              _HeroBadge('CARGA $load'),
            ],
          ),
          const SizedBox(height: 14),
          Text('Olá, $firstName! 👋', style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 6),
          Text(contextText, style: const TextStyle(color: Color(0xFFD5E2E5), height: 1.5)),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(20)),
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w900)),
      );
}

class _CurrentClassActions extends StatelessWidget {
  const _CurrentClassActions({required this.state, required this.session});
  final AppState state;
  final ClassSession session;

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppColors.gold),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Aproveite a aula atual sem sair do fluxo.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: () => showQuickClassNote(context, state, session),
              icon: const Icon(Icons.note_add_outlined),
              label: const Text('Nota rápida'),
            ),
          ],
        ),
      );
}

class _SmartSummary extends StatelessWidget {
  const _SmartSummary({required this.state, required this.smart, required this.overdue, required this.insightCount});
  final AppState state;
  final V26Controller smart;
  final int overdue;
  final int insightCount;

  @override
  Widget build(BuildContext context) {
    final attendance = state.averageAttendance;
    final loadScore = smart.dailyLoadScore(DateTime.now());
    final items = [
      _Metric(Icons.bolt_rounded, 'Carga de hoje', smart.dailyLoadLabel(DateTime.now()), '$loadScore/100'),
      _Metric(Icons.task_alt_rounded, 'Pendências', '${state.pendingCount}', overdue == 0 ? 'nenhuma atrasada' : '$overdue atrasada${overdue == 1 ? '' : 's'}', danger: overdue > 0),
      _Metric(Icons.how_to_reg_rounded, 'Frequência', attendance == null ? '—' : '${attendance.toStringAsFixed(1)}%', '${state.pendingAttendance.length} presença${state.pendingAttendance.length == 1 ? '' : 's'} pendente${state.pendingAttendance.length == 1 ? '' : 's'}'),
      _Metric(Icons.notifications_active_outlined, 'Avisos', '$insightCount', insightCount == 0 ? 'rotina tranquila' : 'itens para revisar', danger: insightCount > 0),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 4 : c.maxWidth >= 600 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: cols == 1 ? 3 : 1.55,
          ),
          itemBuilder: (_, index) => items[index],
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.label, this.value, this.caption, {this.danger = false});
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final bool danger;

  @override
  Widget build(BuildContext context) => SoftCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (danger ? AppColors.danger : Theme.of(context).colorScheme.primary).withValues(alpha: .09),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: danger ? AppColors.danger : null),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                  Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: danger ? AppColors.danger : null)),
                  Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ],
        ),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.state, required this.smart});
  final AppState state;
  final V26Controller smart;

  @override
  Widget build(BuildContext context) {
    final current = state.currentSession;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push(context, motionRoute(const WeeklyPlannerScreen())),
          icon: const Icon(Icons.view_week_outlined),
          label: const Text('Minha semana'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push(context, motionRoute(const TaskFocusScreen())),
          icon: const Icon(Icons.bolt_rounded),
          label: const Text('Foco de tarefas'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push(context, motionRoute(const AttendanceReviewScreen())),
          icon: const Icon(Icons.how_to_reg_rounded),
          label: const Text('Presença'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push(context, motionRoute(const GradeLabScreen())),
          icon: const Icon(Icons.calculate_outlined),
          label: const Text('Notas'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.push(context, motionRoute(const NotificationCenterScreen())),
          icon: const Icon(Icons.notifications_none_rounded),
          label: const Text('Avisos'),
        ),
        OutlinedButton.icon(
          onPressed: () => showTaskEditor(context, state),
          icon: const Icon(Icons.add_task_rounded),
          label: const Text('Novo prazo'),
        ),
        OutlinedButton.icon(
          onPressed: () => showStudyBlockEditor(context, state),
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Planejar estudo'),
        ),
        if (current != null)
          OutlinedButton.icon(
            onPressed: () => showQuickClassNote(context, state, current),
            icon: const Icon(Icons.note_add_outlined),
            label: const Text('Nota da aula'),
          ),
      ],
    );
  }
}

class _PriorityPanel extends StatelessWidget {
  const _PriorityPanel({required this.state, required this.tasks});
  final AppState state;
  final List<AcademicTask> tasks;

  @override
  Widget build(BuildContext context) => SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Prioridades agora',
              trailing: TextButton(
                onPressed: () => Navigator.push(context, motionRoute(const TaskFocusScreen())),
                child: const Text('Abrir foco'),
              ),
            ),
            const SizedBox(height: 8),
            if (tasks.isEmpty) Text('Nenhuma atividade pendente.', style: Theme.of(context).textTheme.bodySmall),
            for (var i = 0; i < tasks.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => showTaskEditor(context, state, task: tasks[i]),
                leading: CircleAvatar(
                  backgroundColor: _taskColor(tasks[i]).withValues(alpha: .10),
                  child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w900, color: _taskColor(tasks[i]))),
                ),
                title: Text(tasks[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${state.subjectName(tasks[i].subjectId)} • ${_taskDue(tasks[i])}'),
                trailing: Icon(tasks[i].kind == TaskKind.exam ? Icons.quiz_outlined : Icons.chevron_right_rounded, color: _taskColor(tasks[i])),
              ),
          ],
        ),
      );
}

class _StudyPanel extends StatelessWidget {
  const _StudyPanel({required this.state, required this.smart, required this.items});
  final AppState state;
  final V26Controller smart;
  final List<StudyBlock> items;

  @override
  Widget build(BuildContext context) => SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Estudo de hoje',
              trailing: IconButton.filledTonal(
                tooltip: 'Adicionar bloco',
                onPressed: () => showStudyBlockEditor(context, state),
                icon: const Icon(Icons.add_rounded),
              ),
            ),
            const SizedBox(height: 8),
            if (items.isEmpty) ...[
              Text('Nenhum bloco planejado.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => showStudyBlockEditor(context, state),
                icon: const Icon(Icons.auto_awesome_outlined),
                label: const Text('Planejar meu primeiro bloco'),
              ),
            ] else
              for (final block in items)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: block.completed,
                  onChanged: (_) => smart.toggleStudyBlock(block),
                  title: Text(block.title, style: TextStyle(fontWeight: FontWeight.w800, decoration: block.completed ? TextDecoration.lineThrough : null)),
                  subtitle: Text('${_time(block.startsAt)} • ${compactDuration(block.durationMinutes)}${block.subjectId == null ? '' : ' • ${state.subjectName(block.subjectId)}'}'),
                ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => Navigator.push(context, motionRoute(const WeeklyPlannerScreen())),
              icon: const Icon(Icons.view_week_outlined),
              label: const Text('Ver semana completa'),
            ),
          ],
        ),
      );
}

class _AttentionPanel extends StatelessWidget {
  const _AttentionPanel({required this.state, required this.smart, required this.insights});
  final AppState state;
  final V26Controller smart;
  final List<AcademicInsight> insights;

  @override
  Widget build(BuildContext context) => SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              'Atenção acadêmica',
              trailing: TextButton(
                onPressed: () => Navigator.push(context, motionRoute(const NotificationCenterScreen())),
                child: const Text('Central de avisos'),
              ),
            ),
            const SizedBox(height: 8),
            if (insights.isEmpty)
              Row(children: [
                const Icon(Icons.verified_rounded, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(child: Text('Nenhum alerta importante no momento.', style: Theme.of(context).textTheme.bodySmall)),
              ])
            else
              for (final insight in insights)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_insightIcon(insight.kind), color: _insightColor(insight.severity)),
                  title: Text(insight.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(insight.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: 'Dispensar',
                    onPressed: () => smart.dismissInsight(insight.id),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
          ],
        ),
      );
}

bool _isOverdue(DateTime dueDate) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(dueDate.year, dueDate.month, dueDate.day).isBefore(today);
}

String _taskDue(AcademicTask task) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
  final days = due.difference(today).inDays;
  if (days < 0) return '${days.abs()}d atrasada';
  if (days == 0) return 'Hoje';
  if (days == 1) return 'Amanhã';
  return 'Em $days dias';
}

Color _taskColor(AcademicTask task) {
  final score = taskUrgencyScore(task);
  if (score >= 100) return AppColors.danger;
  if (score >= 65) return AppColors.warning;
  return AppColors.gold;
}

IconData _insightIcon(InsightKind kind) => switch (kind) {
      InsightKind.task => Icons.task_alt_outlined,
      InsightKind.attendance => Icons.how_to_reg_rounded,
      InsightKind.exam => Icons.quiz_outlined,
      InsightKind.study => Icons.menu_book_outlined,
      InsightKind.routine => Icons.schedule_rounded,
      InsightKind.performance => Icons.insights_rounded,
    };

Color _insightColor(InsightSeverity severity) => switch (severity) {
      InsightSeverity.critical => AppColors.danger,
      InsightSeverity.attention => AppColors.warning,
      InsightSeverity.info => AppColors.gold,
      InsightSeverity.success => AppColors.success,
    };

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _time(DateTime value) => '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
