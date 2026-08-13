import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';

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
                subtitle: state.tasks.isEmpty ? 'Organize trabalhos, provas e pendências.' : '${state.pendingCount} pendente${state.pendingCount == 1 ? '' : 's'} no momento.',
                action: FilledButton.icon(
                  onPressed: () => showTaskEditor(context, state),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Adicionar'),
                ),
              ),
              const SizedBox(height: 16),
              if (state.tasks.isNotEmpty)
                Align(
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
                  duration: const Duration(milliseconds: 250),
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
      _KanbanColumn(title: 'A Fazer', icon: Icons.radio_button_unchecked_rounded, tasks: state.tasks.where((e) => e.status == TaskStatus.todo).toList(), state: state),
      _KanbanColumn(title: 'Em Andamento', icon: Icons.timelapse_rounded, tasks: state.tasks.where((e) => e.status == TaskStatus.doing).toList(), state: state),
      _KanbanColumn(title: 'Concluído', icon: Icons.task_alt_rounded, tasks: state.tasks.where((e) => e.status == TaskStatus.done).toList(), state: state),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth >= 920) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columns.length; i++) ...[
                Expanded(child: columns[i]),
                if (i < columns.length - 1) const SizedBox(width: 11),
              ],
            ],
          );
        }
        return Column(
          children: [
            for (var i = 0; i < columns.length; i++) ...[
              columns[i],
              if (i < columns.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({required this.title, required this.icon, required this.tasks, required this.state});
  final String title;
  final IconData icon;
  final List<AcademicTask> tasks;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .30)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 19),
              const SizedBox(width: 7),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
              GoldBadge('${tasks.length}'),
            ],
          ),
          const SizedBox(height: 10),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 25),
              child: Text('Nenhuma atividade', style: Theme.of(context).textTheme.bodySmall),
            ),
          for (final task in tasks)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _TaskCard(state: state, task: task),
            ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
    final days = due.difference(today).inDays;
    final dueText = days < 0 ? '${days.abs()}d atrasada' : days == 0 ? 'Hoje' : days == 1 ? 'Amanhã' : 'Em $days dias';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: glow ? [BoxShadow(blurRadius: 24, spreadRadius: 2, color: AppColors.gold.withValues(alpha: .28))] : null,
      ),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PriorityBadge(task.priority),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') await showTaskEditor(context, widget.state, task: task);
                    if (value == 'todo') await widget.state.moveTask(task, TaskStatus.todo);
                    if (value == 'doing') await widget.state.moveTask(task, TaskStatus.doing);
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
              ],
            ),
            const SizedBox(height: 6),
            Text(task.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            const SizedBox(height: 3),
            Text(widget.state.subjectName(task.subjectId), style: Theme.of(context).textTheme.bodySmall),
            if (task.checklist.isNotEmpty) ...[
              const SizedBox(height: 9),
              LinearProgressIndicator(
                value: task.checklist.isEmpty ? 0 : task.completedSteps.length / task.checklist.length,
                minHeight: 6,
                borderRadius: BorderRadius.circular(20),
              ),
              const SizedBox(height: 4),
              Text('${task.completedSteps.length}/${task.checklist.length} etapas', style: Theme.of(context).textTheme.labelSmall),
            ],
            const SizedBox(height: 11),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: days <= 1 && task.status != TaskStatus.done ? AppColors.danger : null),
                const SizedBox(width: 5),
                Expanded(child: Text(dueText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: days <= 1 && task.status != TaskStatus.done ? AppColors.danger : null))),
                IconButton.filledTonal(
                  tooltip: task.status == TaskStatus.done ? 'Reabrir' : 'Avançar',
                  onPressed: () async {
                    if (task.status == TaskStatus.todo) await widget.state.moveTask(task, TaskStatus.doing);
                    if (task.status == TaskStatus.doing) await _complete(task);
                    if (task.status == TaskStatus.done) await widget.state.moveTask(task, TaskStatus.todo);
                  },
                  icon: Icon(task.status == TaskStatus.done ? Icons.refresh_rounded : task.status == TaskStatus.doing ? Icons.check_rounded : Icons.arrow_forward_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _complete(AcademicTask task) async {
    setState(() => glow = true);
    await Future.delayed(const Duration(milliseconds: 380));
    await widget.state.moveTask(task, TaskStatus.done);
    if (mounted) {
      setState(() => glow = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atividade concluída ✨')));
    }
  }
}

class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge(this.priority);
  final Priority priority;

  @override
  Widget build(BuildContext context) {
    final label = priority == Priority.high ? 'ALTA' : priority == Priority.medium ? 'MÉDIA' : 'BAIXA';
    final color = priority == Priority.high ? AppColors.danger : priority == Priority.medium ? AppColors.gold : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
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
    const week = ['SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    const months = ['', 'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho', 'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];

    return SoftCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded),
              const SizedBox(width: 8),
              Expanded(child: Text('${months[now.month]} ${now.year}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
            ],
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 7,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 2),
            itemBuilder: (_, i) => Center(child: Text(week[i], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: offset + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: 1.05),
            itemBuilder: (_, i) {
              if (i < offset) return const SizedBox.shrink();
              final day = i - offset + 1;
              final count = state.tasks.where((t) => t.dueDate.year == now.year && t.dueDate.month == now.month && t.dueDate.day == day).length;
              final today = day == now.day;
              return Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: today ? Theme.of(context).colorScheme.primary.withValues(alpha: .11) : null,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: today ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor.withValues(alpha: .28)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$day', style: TextStyle(fontWeight: today ? FontWeight.w900 : FontWeight.w600)),
                    const Spacer(),
                    if (count > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: .13), borderRadius: BorderRadius.circular(6)),
                        child: Text('$count prazo${count == 1 ? '' : 's'}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 7, color: AppColors.gold, fontWeight: FontWeight.w900)),
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
}
