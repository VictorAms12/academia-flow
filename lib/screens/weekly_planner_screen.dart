import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/v26_models.dart';
import '../state/app_state.dart';
import '../state/v26_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/v26_actions.dart';

class WeeklyPlannerScreen extends StatefulWidget {
  const WeeklyPlannerScreen({super.key});

  @override
  State<WeeklyPlannerScreen> createState() => _WeeklyPlannerScreenState();
}

class _WeeklyPlannerScreenState extends State<WeeklyPlannerScreen> {
  final smart = V26Controller.instance;
  DateTime anchor = _mondayOf(DateTime.now());
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    final state = AppStateScope.of(context);
    smart.initialize(state);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    smart.bind(state);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha semana'),
        actions: [
          IconButton(
            tooltip: 'Voltar para esta semana',
            onPressed: () => setState(() => anchor = _mondayOf(DateTime.now())),
            icon: const Icon(Icons.today_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showStudyBlockEditor(context, state),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Planejar estudo'),
      ),
      body: AnimatedBuilder(
        animation: smart,
        builder: (context, _) {
          if (smart.loading && !smart.initialized) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WeekHeader(
                        anchor: anchor,
                        onPrevious: () => setState(() => anchor = anchor.subtract(const Duration(days: 7))),
                        onNext: () => setState(() => anchor = anchor.add(const Duration(days: 7))),
                      ),
                      const SizedBox(height: 14),
                      _LoadOverview(anchor: anchor, state: state, smart: smart),
                      const SizedBox(height: 18),
                      for (var offset = 0; offset < 7; offset++) ...[
                        _DayPlanner(
                          date: anchor.add(Duration(days: offset)),
                          state: state,
                          smart: smart,
                        ),
                        if (offset < 6) const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.anchor, required this.onPrevious, required this.onNext});
  final DateTime anchor;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final end = anchor.add(const Duration(days: 6));
    return SoftCard(
      child: Row(
        children: [
          IconButton.filledTonal(onPressed: onPrevious, icon: const Icon(Icons.chevron_left_rounded)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('PLANEJAMENTO SEMANAL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.gold)),
                const SizedBox(height: 3),
                Text(
                  '${_date(anchor)} — ${_date(end)}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(onPressed: onNext, icon: const Icon(Icons.chevron_right_rounded)),
        ],
      ),
    );
  }
}

class _LoadOverview extends StatelessWidget {
  const _LoadOverview({required this.anchor, required this.state, required this.smart});
  final DateTime anchor;
  final AppState state;
  final V26Controller smart;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Carga da semana'),
          const SizedBox(height: 12),
          for (var i = 0; i < 7; i++) ...[
            Builder(
              builder: (_) {
                final date = anchor.add(Duration(days: i));
                final score = smart.dailyLoadScore(date);
                final label = smart.dailyLoadLabel(date);
                final color = score >= 70 ? AppColors.danger : score >= 38 ? AppColors.warning : AppColors.success;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 42, child: Text(_weekdayShort(date.weekday), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11))),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(value: score / 100, minHeight: 8, color: color),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(width: 46, child: Text(label, textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color))),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DayPlanner extends StatelessWidget {
  const _DayPlanner({required this.date, required this.state, required this.smart});
  final DateTime date;
  final AppState state;
  final V26Controller smart;

  @override
  Widget build(BuildContext context) {
    final sessions = state.sessionsForDate(date).where((session) => session.status != AttendanceStatus.cancelled).toList();
    final tasks = state.tasks.where((task) => task.status != TaskStatus.done && _sameDay(task.dueDate, date)).toList();
    final study = smart.studyBlocksForDate(date);
    final today = _sameDay(date, DateTime.now());

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: today ? Theme.of(context).colorScheme.primary.withValues(alpha: .12) : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(14),
                  border: today ? Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: .35)) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_weekdayShort(date.weekday), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
                    Text('${date.day}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_weekdayLong(date.weekday), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    Text(
                      '${sessions.length} aula${sessions.length == 1 ? '' : 's'} • ${tasks.length} prazo${tasks.length == 1 ? '' : 's'} • ${study.length} bloco${study.length == 1 ? '' : 's'} de estudo',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => showStudyBlockEditor(context, state, initialDate: date),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Estudo'),
              ),
            ],
          ),
          if (sessions.isEmpty && tasks.isEmpty && study.isEmpty) ...[
            const SizedBox(height: 12),
            Text('Dia livre no planejamento atual.', style: Theme.of(context).textTheme.bodySmall),
          ],
          if (sessions.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final session in sessions)
              _TimelineItem(
                icon: Icons.school_outlined,
                title: state.subjectName(session.subjectId),
                subtitle: '${session.start}–${session.end}${session.room.isEmpty ? '' : ' • ${session.room}'}',
                accent: Theme.of(context).colorScheme.primary,
              ),
          ],
          if (study.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final block in study)
              _StudyItem(block: block, state: state, smart: smart),
          ],
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final task in tasks)
              _TimelineItem(
                icon: task.kind == TaskKind.exam ? Icons.quiz_outlined : Icons.task_alt_outlined,
                title: task.title,
                subtitle: '${state.subjectName(task.subjectId)} • entrega neste dia',
                accent: task.priority == Priority.high ? AppColors.danger : AppColors.gold,
              ),
          ],
        ],
      ),
    );
  }
}

class _StudyItem extends StatelessWidget {
  const _StudyItem({required this.block, required this.state, required this.smart});
  final StudyBlock block;
  final AppState state;
  final V26Controller smart;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: block.completed ? .045 : .085),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Checkbox(value: block.completed, onChanged: (_) => smart.toggleStudyBlock(block)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  block.title,
                  style: TextStyle(fontWeight: FontWeight.w900, decoration: block.completed ? TextDecoration.lineThrough : null),
                ),
                Text(
                  '${_time(block.startsAt)} • ${compactDuration(block.durationMinutes)}${block.subjectId == null ? '' : ' • ${state.subjectName(block.subjectId)}'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (block.note.isNotEmpty) Text(block.note, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') await showStudyBlockEditor(context, state, block: block);
              if (value == 'delete') await smart.deleteStudyBlock(block);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'delete', child: Text('Excluir')),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.icon, required this.title, required this.subtitle, required this.accent});
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: accent.withValues(alpha: .055), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ],
        ),
      );
}

DateTime _mondayOf(DateTime value) {
  final day = DateTime(value.year, value.month, value.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
String _time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
String _weekdayShort(int day) => const ['', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'][day.clamp(1, 7)];
String _weekdayLong(int day) => const ['', 'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira', 'Sexta-feira', 'Sábado', 'Domingo'][day.clamp(1, 7)];
