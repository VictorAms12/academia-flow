import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

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
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Atividades & Prazos',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                )),
                        const SizedBox(height: 4),
                        Text('${state.pendingCount} itens precisam da sua atenção.',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, icon: Icon(Icons.view_kanban_rounded), label: Text('Kanban')),
                      ButtonSegment(value: false, icon: Icon(Icons.calendar_month_rounded), label: Text('Calendário')),
                    ],
                    selected: {state.kanbanMode},
                    onSelectionChanged: (v) => state.setKanbanMode(v.first),
                    showSelectedIcon: false,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: state.kanbanMode
                    ? _Kanban(key: const ValueKey('kanban'), state: state)
                    : _AcademicCalendar(key: const ValueKey('calendar'), tasks: state.tasks),
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
    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 920;
        final columns = [
          _KanbanColumn(
            title: 'A Fazer',
            icon: Icons.radio_button_unchecked_rounded,
            tasks: state.tasks.where((e) => e.status == TaskStatus.todo).toList(),
            next: TaskStatus.doing,
            state: state,
          ),
          _KanbanColumn(
            title: 'Em Andamento',
            icon: Icons.timelapse_rounded,
            tasks: state.tasks.where((e) => e.status == TaskStatus.doing).toList(),
            next: TaskStatus.done,
            state: state,
          ),
          _KanbanColumn(
            title: 'Concluído',
            icon: Icons.task_alt_rounded,
            tasks: state.tasks.where((e) => e.status == TaskStatus.done).toList(),
            next: TaskStatus.todo,
            state: state,
          ),
        ];
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columns.length; i++) ...[
                Expanded(child: columns[i]),
                if (i < columns.length - 1) const SizedBox(width: 12),
              ]
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < columns.length; i++) ...[
              columns[i],
              if (i < columns.length - 1) const SizedBox(height: 14),
            ]
          ],
        );
      },
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.title,
    required this.icon,
    required this.tasks,
    required this.next,
    required this.state,
  });
  final String title;
  final IconData icon;
  final List<AcademicTask> tasks;
  final TaskStatus next;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 19),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
              GoldBadge('${tasks.length}'),
            ],
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text('Nenhuma atividade', style: Theme.of(context).textTheme.bodySmall),
            ),
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TaskCard(task: task, next: next, state: state),
            ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatefulWidget {
  const _TaskCard({required this.task, required this.next, required this.state});
  final AcademicTask task;
  final TaskStatus next;
  final AppState state;

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool glow = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final days = task.dueDate.difference(DateTime.now()).inDays + 1;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: glow
            ? [
                BoxShadow(
                  blurRadius: 24,
                  spreadRadius: 2,
                  color: AppColors.gold.withValues(alpha: .30),
                )
              ]
            : null,
      ),
      child: SoftCard(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _priority(task.priority),
                const Spacer(),
                PopupMenuButton<TaskStatus>(
                  onSelected: (status) => widget.state.moveTask(task, status),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: TaskStatus.todo, child: Text('Mover para A Fazer')),
                    PopupMenuItem(value: TaskStatus.doing, child: Text('Mover para Em Andamento')),
                    PopupMenuItem(value: TaskStatus.done, child: Text('Marcar como Concluído')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(task.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 4),
            Text(task.subject, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 13),
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 15, color: days <= 2 ? AppColors.danger : null),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    days < 0 ? 'Prazo expirado' : days == 0 ? 'Hoje' : days == 1 ? 'Amanhã' : 'Em $days dias',
                    style: TextStyle(
                      fontSize: 12,
                      color: days <= 2 ? AppColors.danger : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: task.status == TaskStatus.done ? 'Reabrir' : 'Avançar',
                  onPressed: () async {
                    if (widget.next == TaskStatus.done) {
                      setState(() => glow = true);
                      await Future.delayed(const Duration(milliseconds: 420));
                      if (mounted) setState(() => glow = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Atividade concluída ✨')),
                        );
                      }
                    }
                    widget.state.moveTask(task, widget.next);
                  },
                  icon: Icon(widget.next == TaskStatus.done
                      ? Icons.check_rounded
                      : widget.next == TaskStatus.todo
                          ? Icons.refresh_rounded
                          : Icons.arrow_forward_rounded),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _priority(Priority p) {
    final text = p == Priority.high ? 'ALTA' : p == Priority.medium ? 'MÉDIA' : 'BAIXA';
    final color = p == Priority.high
        ? AppColors.danger
        : p == Priority.medium
            ? AppColors.gold
            : const Color(0xFF67A8B5);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
    );
  }
}

class _AcademicCalendar extends StatelessWidget {
  const _AcademicCalendar({super.key, required this.tasks});
  final List<AcademicTask> tasks;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final first = DateTime(now.year, now.month, 1);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final offset = first.weekday - 1;
    const week = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];

    return SoftCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${_monthName(now.month)} ${now.year}',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
              const GoldBadge('CALENDÁRIO ACADÊMICO'),
            ],
          ),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 2),
            itemBuilder: (_, i) => Center(
              child: Text(week[i], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: offset + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 5,
              mainAxisSpacing: 5,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (_, i) {
              if (i < offset) return const SizedBox.shrink();
              final day = i - offset + 1;
              final date = DateTime(now.year, now.month, day);
              final taskCount = tasks.where((t) =>
                  t.dueDate.year == date.year &&
                  t.dueDate.month == date.month &&
                  t.dueDate.day == date.day).length;
              final today = day == now.day;
              return Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: today ? Theme.of(context).colorScheme.primary.withValues(alpha: .12) : null,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: today ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor.withValues(alpha: .35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$day', style: TextStyle(fontWeight: today ? FontWeight.w900 : FontWeight.w600)),
                    const Spacer(),
                    if (taskCount > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '$taskCount prazo${taskCount > 1 ? 's' : ''}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppColors.gold),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static String _monthName(int month) => const [
    '', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'
  ][month];
}
