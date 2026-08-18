import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import '../widgets/v22_actions.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Atividades & Prazos',
                subtitle: state.tasks.isEmpty
                    ? 'Organize trabalhos, provas e pendências.'
                    : '${state.pendingCount} pendente${state.pendingCount == 1 ? '' : 's'} no momento.',
                action: FilledButton.icon(
                  onPressed: () => showTaskEditor(context, state),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Adicionar'),
                ),
              ),
              const SizedBox(height: 16),
              if (state.tasks.isNotEmpty)
                MotionEntrance(
                  delay: const Duration(milliseconds: 70),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, icon: Icon(Icons.view_kanban_rounded), label: Text('Kanban')),
                        ButtonSegment(value: false, icon: Icon(Icons.calendar_month_rounded), label: Text('Calendário')),
                      ],
                      selected: {state.kanbanMode},
                      onSelectionChanged: (v) => state.setKanbanMode(v.first),
                      showSelectedIcon: false,
                    ),
                  ),
                ),
              if (state.tasks.isNotEmpty) const SizedBox(height: 14),
              if (state.tasks.isEmpty)
                EmptyState(
                  icon: Icons.assignment_turned_in_outlined,
                  title: 'Nenhuma atividade cadastrada',
                  message: 'Adicione provas, trabalhos, listas, projetos e outros prazos. Você poderá mover cada item pelo Kanban e marcar etapas concluídas.',
                  actionLabel: 'Adicionar primeira atividade',
                  onAction: () => showTaskEditor(context, state),
                )
              else
                AnimatedSwitcher(
                  duration: MotionSpec.normal,
                  switchInCurve: MotionSpec.curve,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: .992, end: 1).animate(animation),
                      child: child,
                    ),
                  ),
                  child: state.kanbanMode
                      ? _Kanban(key: const ValueKey('kanban'), state: state)
                      : _Calendar(key: const ValueKey('calendar'), state: state),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Kanban extends StatelessWidget {
  const _Kanban({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final columns = [
      _KanbanColumn(title: 'A Fazer', icon: Icons.radio_button_unchecked_rounded, tasks: state.tasks.where((e) => e.status == TaskStatus.todo).toList(), state: state, entranceOffset: const Offset(-.025, 0)),
      _KanbanColumn(title: 'Em Andamento', icon: Icons.timelapse_rounded, tasks: state.tasks.where((e) => e.status == TaskStatus.doing).toList(), state: state, entranceOffset: const Offset(0, .025)),
      _KanbanColumn(title: 'Concluído', icon: Icons.task_alt_rounded, tasks: state.tasks.where((e) => e.status == TaskStatus.done).toList(), state: state, entranceOffset: const Offset(.025, 0)),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 920) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columns.length; i++) ...[
                Expanded(child: MotionEntrance(delay: Duration(milliseconds: i * 55), offset: columns[i].entranceOffset, child: columns[i])),
                if (i < columns.length - 1) const SizedBox(width: 11),
              ],
            ],
          );
        }
        return Column(children: [
          for (var i = 0; i < columns.length; i++) ...[
            MotionEntrance(delay: Duration(milliseconds: i * 45), offset: const Offset(0, .035), child: columns[i]),
            if (i < columns.length - 1) const SizedBox(height: 12),
          ],
        ]);
      },
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({required this.title, required this.icon, required this.tasks, required this.state, required this.entranceOffset});
  final String title;
  final IconData icon;
  final List<AcademicTask> tasks;
  final AppState state;
  final Offset entranceOffset;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: MotionSpec.normal,
      curve: MotionSpec.curve,
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .035),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .30)),
        ),
        child: Column(children: [
          Row(children: [
            Icon(icon, size: 19),
            const SizedBox(width: 7),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
            AnimatedSwitcher(duration: MotionSpec.fast, child: GoldBadge('${tasks.length}', key: ValueKey(tasks.length))),
          ]),
          const SizedBox(height: 10),
          if (tasks.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 25), child: Text('Nenhuma atividade', style: Theme.of(context).textTheme.bodySmall)),
          for (var i = 0; i < tasks.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: MotionEntrance(
                key: ValueKey('task-${tasks[i].id}-${tasks[i].status.name}'),
                delay: Duration(milliseconds: (i > 5 ? 5 : i) * 35),
                offset: const Offset(0, .055),
                child: _TaskCard(state: state, task: tasks[i]),
              ),
            ),
        ]),
      ),
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({required this.state, required this.task});
  final AppState state;
  final AcademicTask task;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool glow = false;
  bool checklistOpen = false;
  bool mutating = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    final days = due.difference(today).inDays;
    final dueText = task.status == TaskStatus.done
        ? 'Concluída'
        : days < 0
            ? '${days.abs()}d atrasada'
            : days == 0
                ? 'Hoje'
                : days == 1
                    ? 'Amanhã'
                    : 'Em $days dias';
    final progress = task.checklist.isEmpty ? 0.0 : task.completedSteps.length / task.checklist.length;

    return AnimatedScale(
      scale: glow ? 1.018 : 1,
      duration: MotionSpec.fast,
      curve: MotionSpec.spring,
      child: AnimatedContainer(
        duration: MotionSpec.emphasized,
        curve: MotionSpec.curve,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: glow ? [BoxShadow(blurRadius: 28, spreadRadius: 2, color: AppColors.gold.withValues(alpha: .30))] : null,
        ),
        child: SoftCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              _PriorityBadge(task.priority),
              const SizedBox(width: 7),
              AnimatedSwitcher(duration: MotionSpec.fast, child: task.status == TaskStatus.done ? const Icon(Icons.check_circle_rounded, key: ValueKey('done'), color: AppColors.success, size: 19) : const SizedBox.shrink(key: ValueKey('pending'))),
              const Spacer(),
              PopupMenuButton<String>(
                enabled: !mutating,
                onSelected: (value) async {
                  if (value == 'edit') await showTaskEditor(context, widget.state, task: task);
                  if (value == 'todo') await _move(task, TaskStatus.todo);
                  if (value == 'doing') await _move(task, TaskStatus.doing);
                  if (value == 'done') await _complete(task);
                  if (value == 'delete' && await confirmDelete(context, task.title)) await widget.state.deleteTask(task);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'todo', child: Text('Mover para A Fazer')),
                  PopupMenuItem(value: 'doing', child: Text('Mover para Em Andamento')),
                  PopupMenuItem(value: 'done', child: Text('Marcar como Concluído')),
                  PopupMenuDivider(),
                  PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              ),
            ]),
            const SizedBox(height: 6),
            AnimatedDefaultTextStyle(
              duration: MotionSpec.fast,
              curve: MotionSpec.curve,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w900, fontSize: 15, decoration: task.status == TaskStatus.done ? TextDecoration.lineThrough : TextDecoration.none, decorationColor: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: .55)),
              child: Text(task.title),
            ),
            const SizedBox(height: 3),
            Text(widget.state.subjectName(task.subjectId), style: Theme.of(context).textTheme.bodySmall),
            if (task.checklist.isNotEmpty) ...[
              const SizedBox(height: 9),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => setState(() => checklistOpen = !checklistOpen),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(children: [
                    Expanded(child: MotionProgress(value: progress, minHeight: 6)),
                    const SizedBox(width: 9),
                    AnimatedSwitcher(duration: MotionSpec.fast, child: Text('${task.completedSteps.length}/${task.checklist.length}', key: ValueKey(task.completedSteps.length), style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800))),
                    const SizedBox(width: 3),
                    AnimatedRotation(turns: checklistOpen ? .5 : 0, duration: MotionSpec.fast, curve: MotionSpec.curve, child: const Icon(Icons.keyboard_arrow_down_rounded, size: 19)),
                  ]),
                ),
              ),
              AnimatedSize(
                duration: MotionSpec.normal,
                curve: MotionSpec.curve,
                child: checklistOpen
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(children: [
                          for (var i = 0; i < task.checklist.length; i++)
                            _ChecklistRow(
                              key: ValueKey('${task.id}-step-$i-${task.completedSteps.contains(i)}'),
                              label: task.checklist[i],
                              checked: task.completedSteps.contains(i),
                              enabled: !mutating,
                              onChanged: () => _toggleStep(task, i),
                            ),
                        ]),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
            const SizedBox(height: 11),
            Row(children: [
              Icon(Icons.schedule_rounded, size: 15, color: days <= 1 && task.status != TaskStatus.done ? AppColors.danger : task.status == TaskStatus.done ? AppColors.success : null),
              const SizedBox(width: 5),
              Expanded(child: Text(dueText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: days <= 1 && task.status != TaskStatus.done ? AppColors.danger : task.status == TaskStatus.done ? AppColors.success : null))),
              AnimatedSwitcher(
                duration: MotionSpec.fast,
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: IconButton.filledTonal(
                  key: ValueKey(task.status),
                  tooltip: task.status == TaskStatus.done ? 'Reabrir' : 'Avançar',
                  onPressed: mutating
                      ? null
                      : () async {
                          if (task.status == TaskStatus.todo) await _move(task, TaskStatus.doing);
                          if (task.status == TaskStatus.doing) await _complete(task);
                          if (task.status == TaskStatus.done) await _move(task, TaskStatus.todo);
                        },
                  icon: Icon(task.status == TaskStatus.done ? Icons.refresh_rounded : task.status == TaskStatus.doing ? Icons.check_rounded : Icons.arrow_forward_rounded),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _toggleStep(AcademicTask task, int step) async {
    if (mutating) return;
    final wasChecked = task.completedSteps.contains(step);
    final finishesChecklist = !wasChecked && task.completedSteps.length + 1 == task.checklist.length;
    setState(() {
      mutating = true;
      if (finishesChecklist) glow = true;
    });
    try {
      await widget.state.toggleTaskStep(task, step);
      if (finishesChecklist && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checklist completo ✨')));
      }
    } finally {
      if (mounted) setState(() { mutating = false; glow = false; });
    }
  }

  Future<void> _move(AcademicTask task, TaskStatus status) async {
    if (mutating) return;
    setState(() => mutating = true);
    try {
      await widget.state.moveTask(task, status);
    } finally {
      if (mounted) setState(() => mutating = false);
    }
  }

  Future<void> _complete(AcademicTask task) async {
    if (mutating) return;
    setState(() { mutating = true; glow = true; });
    try {
      await widget.state.moveTask(task, TaskStatus.done);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atividade concluída ✨')));
    } finally {
      if (mounted) setState(() { mutating = false; glow = false; });
    }
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({super.key, required this.label, required this.checked, required this.enabled, required this.onChanged});
  final String label;
  final bool checked;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onChanged : null,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Checkbox(value: checked, onChanged: enabled ? (_) => onChanged() : null, visualDensity: VisualDensity.compact),
          const SizedBox(width: 2),
          Expanded(child: AnimatedDefaultTextStyle(duration: MotionSpec.fast, curve: MotionSpec.curve, style: TextStyle(color: checked ? Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: .55) : Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12, fontWeight: checked ? FontWeight.w500 : FontWeight.w600, decoration: checked ? TextDecoration.lineThrough : TextDecoration.none), child: Text(label))),
          AnimatedSwitcher(duration: MotionSpec.fast, transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child), child: checked ? const Icon(Icons.check_rounded, key: ValueKey(true), size: 16, color: AppColors.success) : const SizedBox(width: 16, key: ValueKey(false))),
        ]),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge(this.priority);
  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final label = priority == Priority.high ? 'ALTA' : priority == Priority.medium ? 'MÉDIA' : 'BAIXA';
    final color = priority == Priority.high ? AppColors.danger : priority == Priority.medium ? AppColors.gold : Theme.of(context).colorScheme.primary;
    return AnimatedContainer(duration: MotionSpec.fast, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)));
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final offset = first.weekday - 1;
    final countByDay = <int, int>{};
    for (final task in state.tasks) {
      if (task.dueDate.year != now.year || task.dueDate.month != now.month) continue;
      countByDay[task.dueDate.day] = (countByDay[task.dueDate.day] ?? 0) + 1;
    }
    const week = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    const months = ['', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];

    return SoftCard(
      child: Column(children: [
        Row(children: [const Icon(Icons.calendar_month_rounded), const SizedBox(width: 8), Expanded(child: Text('${months[now.month]} ${now.year}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)))]),
        const SizedBox(height: 14),
        GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: 7, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 2), itemBuilder: (_, i) => Center(child: Text(week[i], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)))),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: offset + daysInMonth,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: 1.05),
          itemBuilder: (_, i) {
            if (i < offset) return const SizedBox.shrink();
            final day = i - offset + 1;
            final count = countByDay[day] ?? 0;
            final today = day == now.day;
            return MotionEntrance(
              delay: Duration(milliseconds: ((i - offset) > 13 ? 13 : (i - offset)) * 12),
              offset: const Offset(0, .08),
              child: AnimatedContainer(
                duration: MotionSpec.fast,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: today ? Theme.of(context).colorScheme.primary.withValues(alpha: .11) : null, borderRadius: BorderRadius.circular(11), border: Border.all(color: today ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor.withValues(alpha: .28))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$day', style: TextStyle(fontWeight: today ? FontWeight.w900 : FontWeight.w600)),
                  const Spacer(),
                  if (count > 0)
                    Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 3), decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: .13), borderRadius: BorderRadius.circular(6)), child: Text('$count prazo${count == 1 ? '' : 's'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 7, color: AppColors.gold, fontWeight: FontWeight.w900))),
                ]),
              ),
            );
          },
        ),
      ]),
    );
  }
}
