import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final upcoming = state.tasks.where((t) => t.status != TaskStatus.done).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final todaySchedules = state.schedules.where((s) => s.day == DateTime.now().weekday).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Hero(state: state, nextTask: upcoming.isEmpty ? null : upcoming.first),
              const SizedBox(height: 18),
              _Metrics(state: state),
              const SizedBox(height: 24),
              const SectionTitle('Acesso rápido'),
              const SizedBox(height: 11),
              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => showTaskEditor(context, state),
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Nova atividade'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => showSubjectEditor(context, state),
                    icon: const Icon(Icons.auto_stories_rounded),
                    label: const Text('Nova matéria'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => showNoteEditor(context, state),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Nova anotação'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => state.setIndex(4),
                    icon: const Icon(Icons.today_rounded),
                    label: const Text('Horário do dia'),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              LayoutBuilder(
                builder: (context, constraints) {
                  final left = _UpcomingPanel(state: state, tasks: upcoming.take(5).toList());
                  final right = _TodayPanel(state: state, schedules: todaySchedules);
                  if (constraints.maxWidth >= 850) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: left),
                        const SizedBox(width: 14),
                        Expanded(flex: 2, child: right),
                      ],
                    );
                  }
                  return Column(children: [left, const SizedBox(height: 14), right]);
                },
              ),
              const SizedBox(height: 24),
              _SubjectsSnapshot(state: state),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.state, required this.nextTask});
  final AppState state;
  final AcademicTask? nextTask;

  @override
  Widget build(BuildContext context) {
    final firstName = state.userName.trim().split(' ').first;
    String subtitle;
    if (nextTask == null) {
      subtitle = state.tasks.isEmpty
          ? 'Seu espaço está pronto. Comece cadastrando suas matérias e atividades.'
          : 'Você não tem atividades pendentes. Bom trabalho!';
    } else {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(nextTask!.dueDate.year, nextTask!.dueDate.month, nextTask!.dueDate.day);
      final days = due.difference(today).inDays;
      final when = days < 0 ? 'está atrasada' : days == 0 ? 'vence hoje' : days == 1 ? 'vence amanhã' : 'vence em $days dias';
      subtitle = '“${nextTask!.title}” $when.';
    }

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
          if (state.semester.isNotEmpty) GoldBadge(state.semester.toUpperCase()),
          if (state.semester.isNotEmpty) const SizedBox(height: 14),
          Text('Olá, $firstName! 👋', style: const TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFFD5E2E5), height: 1.5)),
        ],
      ),
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
      _Metric(icon: Icons.grade_rounded, label: 'Média geral', value: avg == null ? '—' : avg.toStringAsFixed(2), caption: avg == null ? 'Cadastre suas notas' : 'Calculada pelas matérias', color: AppColors.gold),
      _Metric(icon: Icons.done_all_rounded, label: 'Atividades', value: '${state.completedCount}/${state.tasks.length}', caption: '${state.pendingCount} pendente${state.pendingCount == 1 ? '' : 's'}'),
      _Metric(icon: Icons.event_available_rounded, label: 'Frequência', value: attendance == null ? '—' : '${attendance.toStringAsFixed(1)}%', caption: state.subjects.isEmpty ? 'Cadastre suas matérias' : 'Média das disciplinas'),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 760) {
          return Row(children: [
            for (var i = 0; i < items.length; i++) ...[
              Expanded(child: items[i]),
              if (i < items.length - 1) const SizedBox(width: 11),
            ]
          ]);
        }
        return Column(children: [
          for (var i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1) const SizedBox(height: 9),
          ]
        ]);
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.label, required this.value, required this.caption, this.color});
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return SoftCard(
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(color: accent.withValues(alpha: .11), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                Text(caption, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingPanel extends StatelessWidget {
  const _UpcomingPanel({required this.state, required this.tasks});
  final AppState state;
  final List<AcademicTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return EmptyState(
        icon: Icons.task_alt_rounded,
        title: 'Nenhum prazo pendente',
        message: 'Adicione trabalhos, provas ou lembretes para acompanhar os próximos prazos.',
        actionLabel: 'Adicionar atividade',
        onAction: () => showTaskEditor(context, state),
      );
    }
    return SoftCard(
      child: Column(
        children: [
          SectionTitle('Próximos prazos', trailing: TextButton(onPressed: () => state.setIndex(2), child: const Text('Ver todos'))),
          const SizedBox(height: 7),
          for (var i = 0; i < tasks.length; i++) ...[
            _TaskRow(state: state, task: tasks[i]),
            if (i < tasks.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.state, required this.task});
  final AppState state;
  final AcademicTask task;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    final days = due.difference(today).inDays;
    final urgent = days <= 1;
    final label = days < 0 ? '${days.abs()}d ATRASO' : days == 0 ? 'HOJE' : days == 1 ? 'AMANHÃ' : '${days}d';
    return InkWell(
      onTap: () => showTaskEditor(context, state, task: task),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: urgent ? AppColors.danger.withValues(alpha: .10) : Theme.of(context).colorScheme.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: urgent ? AppColors.danger : null)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(state.subjectName(task.subjectId), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GoldBadge(task.priority == Priority.high ? 'ALTA' : task.priority == Priority.medium ? 'MÉDIA' : 'BAIXA'),
          ],
        ),
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.state, required this.schedules});
  final AppState state;
  final List<ScheduleEntry> schedules;

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return EmptyState(
        icon: Icons.calendar_today_rounded,
        title: 'Sem aulas hoje',
        message: state.schedules.isEmpty ? 'Cadastre sua grade semanal para visualizar a rotina diária.' : 'Não há horários cadastrados para hoje.',
        actionLabel: state.subjects.isEmpty ? null : 'Adicionar horário',
        onAction: state.subjects.isEmpty ? null : () => showScheduleEditor(context, state),
      );
    }
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Hoje'),
          const SizedBox(height: 12),
          for (var i = 0; i < schedules.length; i++) ...[
            Row(
              children: [
                Container(width: 4, height: 46, decoration: BoxDecoration(color: i == 0 ? AppColors.gold : Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(4))),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(state.subjectName(schedules[i].subjectId), style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text('${schedules[i].start}–${schedules[i].end}${schedules[i].room.isEmpty ? '' : ' • ${schedules[i].room}'}', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            if (i < schedules.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _SubjectsSnapshot extends StatelessWidget {
  const _SubjectsSnapshot({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (state.subjects.isEmpty) {
      return EmptyState(
        icon: Icons.auto_stories_rounded,
        title: 'Comece pelas suas matérias',
        message: 'Cadastre as disciplinas do semestre. Depois você poderá adicionar notas, faltas, horários, tarefas e materiais.',
        actionLabel: 'Cadastrar primeira matéria',
        onAction: () => showSubjectEditor(context, state),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Resumo das matérias', trailing: TextButton(onPressed: () => state.setIndex(1), child: const Text('Gerenciar'))),
        const SizedBox(height: 11),
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth >= 930 ? 3 : c.maxWidth >= 600 ? 2 : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.subjects.length.clamp(0, 6).toInt(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 11,
                mainAxisSpacing: 11,
                childAspectRatio: cols == 1 ? 2.45 : 1.65,
              ),
              itemBuilder: (_, i) {
                final s = state.subjects[i];
                final avg = s.id == null ? null : state.averageForSubject(s.id!);
                final risk = state.isSubjectAtRisk(s);
                return SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(child: Text(s.name.substring(0, 1).toUpperCase())),
                          const Spacer(),
                          if (risk)
                            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20)
                          else
                            const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 20),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(s.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(child: Text('Média ${avg == null ? '—' : avg.toStringAsFixed(1)}', style: Theme.of(context).textTheme.bodySmall)),
                          Text('${s.attendance.toStringAsFixed(0)}% freq.', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
