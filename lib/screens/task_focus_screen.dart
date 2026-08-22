import 'package:flutter/material.dart';

import '../models/attachment.dart';
import '../models/models.dart';
import '../models/v26_models.dart';
import '../state/app_state.dart';
import '../state/v26_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/v22_actions.dart';
import 'attachment_manager_screen.dart';

enum _TaskFocusFilter { priority, overdue, today, week, exams }

class TaskFocusScreen extends StatefulWidget {
  const TaskFocusScreen({super.key});

  @override
  State<TaskFocusScreen> createState() => _TaskFocusScreenState();
}

class _TaskFocusScreenState extends State<TaskFocusScreen> {
  final smart = V26Controller.instance;
  _TaskFocusFilter filter = _TaskFocusFilter.priority;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    smart.bind(state);
    final tasks = _filtered(state);
    return Scaffold(
      appBar: AppBar(title: const Text('Foco de atividades')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 950),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHeader(
                    title: 'O que merece atenção agora?',
                    subtitle: 'Prioridade calculada por prazo, urgência, status e importância da atividade.',
                  ),
                  const SizedBox(height: 14),
                  _TaskSummary(state: state),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<_TaskFocusFilter>(
                      showSelectedIcon: false,
                      selected: {filter},
                      onSelectionChanged: (value) => setState(() => filter = value.first),
                      segments: const [
                        ButtonSegment(value: _TaskFocusFilter.priority, icon: Icon(Icons.bolt_rounded), label: Text('Prioridade')),
                        ButtonSegment(value: _TaskFocusFilter.overdue, icon: Icon(Icons.warning_amber_rounded), label: Text('Atrasadas')),
                        ButtonSegment(value: _TaskFocusFilter.today, icon: Icon(Icons.today_rounded), label: Text('Hoje')),
                        ButtonSegment(value: _TaskFocusFilter.week, icon: Icon(Icons.date_range_rounded), label: Text('7 dias')),
                        ButtonSegment(value: _TaskFocusFilter.exams, icon: Icon(Icons.quiz_outlined), label: Text('Provas')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (tasks.isEmpty)
                    const EmptyState(
                      icon: Icons.task_alt_rounded,
                      title: 'Nada nesta visão',
                      message: 'Não há atividades pendentes que correspondam a este filtro.',
                    )
                  else
                    for (var i = 0; i < tasks.length; i++) ...[
                      _FocusTaskCard(task: tasks[i], state: state, smart: smart, rank: i + 1),
                      if (i < tasks.length - 1) const SizedBox(height: 9),
                    ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<AcademicTask> _filtered(AppState state) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final all = state.tasks.where((task) => task.status != TaskStatus.done).toList();
    Iterable<AcademicTask> selected = all;
    switch (filter) {
      case _TaskFocusFilter.priority:
        selected = smart.prioritizedTasks(limit: 50);
      case _TaskFocusFilter.overdue:
        selected = all.where((task) => DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day).isBefore(today));
      case _TaskFocusFilter.today:
        selected = all.where((task) => _sameDay(task.dueDate, today));
      case _TaskFocusFilter.week:
        selected = all.where((task) {
          final days = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day).difference(today).inDays;
          return days >= 0 && days <= 7;
        });
      case _TaskFocusFilter.exams:
        selected = all.where((task) => task.kind == TaskKind.exam);
    }
    final items = selected.toList();
    if (filter != _TaskFocusFilter.priority) {
      items.sort((a, b) {
        final urgent = taskUrgencyScore(b).compareTo(taskUrgencyScore(a));
        if (urgent != 0) return urgent;
        return a.dueDate.compareTo(b.dueDate);
      });
    }
    return items;
  }
}

class _TaskSummary extends StatelessWidget {
  const _TaskSummary({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final pending = state.tasks.where((task) => task.status != TaskStatus.done).toList();
    final overdue = pending.where((task) => DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day).isBefore(today)).length;
    final todayCount = pending.where((task) => _sameDay(task.dueDate, today)).length;
    final exams = pending.where((task) => task.kind == TaskKind.exam && task.dueDate.difference(today).inDays <= 7).length;
    return LayoutBuilder(
      builder: (context, c) {
        final cards = [
          _SummaryChip(icon: Icons.pending_actions_rounded, label: 'Pendentes', value: '${pending.length}'),
          _SummaryChip(icon: Icons.warning_amber_rounded, label: 'Atrasadas', value: '$overdue', danger: overdue > 0),
          _SummaryChip(icon: Icons.today_rounded, label: 'Para hoje', value: '$todayCount'),
          _SummaryChip(icon: Icons.quiz_outlined, label: 'Provas / 7 dias', value: '$exams'),
        ];
        if (c.maxWidth >= 700) {
          return Row(children: [for (var i = 0; i < cards.length; i++) ...[Expanded(child: cards[i]), if (i < cards.length - 1) const SizedBox(width: 8)]]);
        }
        return Wrap(spacing: 8, runSpacing: 8, children: cards.map((card) => SizedBox(width: (c.maxWidth - 8) / 2, child: card)).toList());
      },
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label, required this.value, this.danger = false});
  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) => SoftCard(
        padding: const EdgeInsets.all(13),
        child: Row(children: [
          Icon(icon, color: danger ? AppColors.danger : Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
              Text(label, style: Theme.of(context).textTheme.labelSmall),
            ]),
          ),
        ]),
      );
}

class _FocusTaskCard extends StatelessWidget {
  const _FocusTaskCard({required this.task, required this.state, required this.smart, required this.rank});
  final AcademicTask task;
  final AppState state;
  final V26Controller smart;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    final days = due.difference(today).inDays;
    final overdue = days < 0;
    final score = taskUrgencyScore(task);
    final accent = overdue || score >= 100
        ? AppColors.danger
        : score >= 65
            ? AppColors.warning
            : Theme.of(context).colorScheme.primary;
    final progress = task.checklist.isEmpty ? null : task.completedSteps.length / task.checklist.length;

    return SoftCard(
      onTap: () => showTaskEditor(context, state, task: task),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)),
                child: Text('#$rank', style: TextStyle(fontWeight: FontWeight.w900, color: accent, fontSize: 11)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              PopupMenuButton<String>(
                onSelected: (value) => _handleAction(context, value),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  if (task.id != null) const PopupMenuItem(value: 'attachments', child: Text('Anexos')),
                  const PopupMenuItem(value: 'tomorrow', child: Text('Adiar 1 dia')),
                  const PopupMenuItem(value: 'week', child: Text('Adiar 1 semana')),
                  const PopupMenuItem(value: 'duplicate', child: Text('Duplicar')),
                  const PopupMenuDivider(),
                  const PopupMenuItem(value: 'done', child: Text('Marcar como concluída')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('${state.subjectName(task.subjectId)} • ${_kind(task.kind)}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _Pill(label: _deadline(days), icon: Icons.schedule_rounded, color: accent),
              _Pill(label: _priority(task.priority), icon: Icons.flag_outlined, color: _priorityColor(task.priority)),
              if (task.status == TaskStatus.doing) const _Pill(label: 'Em andamento', icon: Icons.timelapse_rounded, color: AppColors.gold),
              if (task.id != null)
                ActionChip(
                  avatar: const Icon(Icons.attach_file_rounded, size: 15),
                  label: const Text('Anexos'),
                  onPressed: () => _openAttachments(context),
                ),
            ],
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (progress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress, minHeight: 7, borderRadius: BorderRadius.circular(20)),
            const SizedBox(height: 5),
            Text('${task.completedSteps.length}/${task.checklist.length} etapas concluídas', style: Theme.of(context).textTheme.labelSmall),
          ],
        ],
      ),
    );
  }

  Future<void> _openAttachments(BuildContext context) async {
    if (task.id == null) return;
    await showAttachmentManager(
      context,
      target: AttachmentTarget(type: AttachmentTargetType.task, id: task.id!, subjectId: task.subjectId),
      title: task.title,
    );
  }

  Future<void> _handleAction(BuildContext context, String value) async {
    if (value == 'edit') {
      await showTaskEditor(context, state, task: task);
      return;
    }
    if (value == 'attachments') {
      await _openAttachments(context);
      return;
    }

    String? message;
    VoidCallback? undo;
    if (value == 'tomorrow') {
      await smart.postponeTask(task, const Duration(days: 1));
      message = 'Prazo adiado em 1 dia.';
      undo = () => state.saveTask(task);
    } else if (value == 'week') {
      await smart.postponeTask(task, const Duration(days: 7));
      message = 'Prazo adiado em 1 semana.';
      undo = () => state.saveTask(task);
    } else if (value == 'duplicate') {
      await smart.duplicateTask(task);
      message = 'Cópia da atividade criada.';
    } else if (value == 'done') {
      await state.moveTask(task, TaskStatus.done);
      message = 'Atividade concluída.';
      undo = () => state.moveTask(task, task.status);
    }

    if (!context.mounted || message == null) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(message),
        action: undo == null ? null : SnackBarAction(label: 'DESFAZER', onPressed: undo),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

String _deadline(int days) {
  if (days < 0) return '${days.abs()}d atrasada';
  if (days == 0) return 'Hoje';
  if (days == 1) return 'Amanhã';
  return 'Em $days dias';
}

String _priority(Priority value) => switch (value) {
      Priority.high => 'Alta',
      Priority.medium => 'Média',
      Priority.low => 'Baixa',
    };
Color _priorityColor(Priority value) => switch (value) {
      Priority.high => AppColors.danger,
      Priority.medium => AppColors.gold,
      Priority.low => AppColors.success,
    };
String _kind(TaskKind value) => switch (value) {
      TaskKind.activity => 'Atividade',
      TaskKind.exam => 'Prova',
      TaskKind.seminar => 'Seminário',
      TaskKind.project => 'Projeto',
      TaskKind.reading => 'Leitura',
      TaskKind.other => 'Outro',
    };
bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
