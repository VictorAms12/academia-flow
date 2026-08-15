import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';
import '../widgets/motion.dart';
import '../widgets/routine_today_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final upcoming = state.tasks.where((t) => t.status != TaskStatus.done).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final firstName = state.userName.trim().split(' ').first;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MotionEntrance(child: _Hero(state: state, firstName: firstName, nextTask: upcoming.isEmpty ? null : upcoming.first)),
            const SizedBox(height: 14),
            MotionEntrance(delay: const Duration(milliseconds: 45), child: RoutineTodayCard(state: state)),
            const SizedBox(height: 14),
            MotionEntrance(delay: const Duration(milliseconds: 90), child: _Metrics(state: state)),
            const SizedBox(height: 20),
            const SectionTitle('Acesso rápido'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.tonalIcon(onPressed: () => showTaskEditor(context, state), icon: const Icon(Icons.add_task_rounded), label: const Text('Novo prazo')),
              FilledButton.tonalIcon(onPressed: () => showSubjectEditor(context, state), icon: const Icon(Icons.auto_stories_rounded), label: const Text('Nova matéria')),
              FilledButton.tonalIcon(onPressed: () => showNoteEditor(context, state), icon: const Icon(Icons.note_add_outlined), label: const Text('Nova anotação')),
              FilledButton.tonalIcon(onPressed: () => state.setIndex(4), icon: const Icon(Icons.school_rounded), label: const Text('Abrir rotina')),
            ]),
            const SizedBox(height: 20),
            LayoutBuilder(builder: (context, c) {
              final deadlines = _Upcoming(state: state, tasks: upcoming.take(6).toList());
              final today = _TodaySummary(state: state);
              if (c.maxWidth >= 850) return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: deadlines), const SizedBox(width: 12), Expanded(flex: 2, child: today)]);
              return Column(children: [deadlines, const SizedBox(height: 12), today]);
            }),
          ]),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.state, required this.firstName, required this.nextTask});
  final AppState state;
  final String firstName;
  final AcademicTask? nextTask;
  @override
  Widget build(BuildContext context) {
    final current = state.currentSession;
    final next = state.nextSession;
    final subtitle = current != null
        ? '${state.subjectName(current.subjectId)} está acontecendo agora.'
        : next != null
            ? 'Próxima aula: ${state.subjectName(next.subjectId)} às ${next.start}.'
            : nextTask != null
                ? 'Próximo prazo: ${nextTask!.title}.'
                : 'Sua rotina acadêmica está em dia.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.petroleum, Color(0xFF123A44), AppColors.petroleumDark], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.gold.withValues(alpha: .16))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (state.semester.isNotEmpty) GoldBadge(state.semester.toUpperCase()),
        if (state.semester.isNotEmpty) const SizedBox(height: 13),
        Text('Olá, $firstName! 👋', style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -1)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Color(0xFFD5E2E5), height: 1.5)),
      ]),
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final avg = state.overallAverage;
    final attendance = state.averageAttendance;
    final items = [
      _Metric(Icons.grade_rounded, 'Média geral', avg == null ? '—' : avg.toStringAsFixed(2), 'Notas cadastradas'),
      _Metric(Icons.task_alt_rounded, 'Atividades', '${state.completedCount}/${state.tasks.length}', '${state.pendingCount} pendentes'),
      _Metric(Icons.how_to_reg_rounded, 'Frequência', attendance == null ? '—' : '${attendance.toStringAsFixed(1)}%', '${state.pendingAttendance.length} presenças pendentes'),
      if (state.streakEnabled) _Metric(Icons.local_fire_department_rounded, 'Sequência', '${state.attendanceStreak}', 'aulas presentes seguidas'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 900 ? items.length : c.maxWidth >= 600 ? 2 : 1;
      return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: cols == 1 ? 3 : 1.55), itemBuilder: (_, i) => items[i]);
    });
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.label, this.value, this.caption);
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  @override
  Widget build(BuildContext context) => SoftCard(child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)), child: Icon(icon)), const SizedBox(width: 11), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: Theme.of(context).textTheme.bodySmall), Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall)]))]));
}

class _Upcoming extends StatelessWidget {
  const _Upcoming({required this.state, required this.tasks});
  final AppState state;
  final List<AcademicTask> tasks;
  @override
  Widget build(BuildContext context) => SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SectionTitle('Próximos prazos', trailing: TextButton(onPressed: () => state.setIndex(2), child: const Text('Ver todos'))),
    const SizedBox(height: 8),
    if (tasks.isEmpty) Text('Nenhum prazo pendente.', style: Theme.of(context).textTheme.bodySmall),
    for (final task in tasks)
      ListTile(contentPadding: EdgeInsets.zero, onTap: () => showTaskEditor(context, state, task: task), leading: const Icon(Icons.assignment_outlined), title: Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${state.subjectName(task.subjectId)} • ${_date(task.dueDate)}')),
  ]));
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final week = state.weeklyAttendanceSummary;
    return SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Resumo da semana'),
      const SizedBox(height: 10),
      _Row('Aulas', '${week['classes'] ?? 0}'),
      _Row('Presenças', '${week['present'] ?? 0}'),
      _Row('Faltas', '${week['absent'] ?? 0}'),
      _Row('Pendentes', '${week['pending'] ?? 0}'),
      const Divider(height: 22),
      Text('${state.dueToday.length} entrega${state.dueToday.length == 1 ? '' : 's'} para hoje', style: const TextStyle(fontWeight: FontWeight.w800)),
    ]));
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))]));
}

String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
