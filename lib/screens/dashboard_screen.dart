import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final pending = state.tasks.where((e) => e.status != TaskStatus.done).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  return _HeroHeader(compact: constraints.maxWidth < 680);
                },
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final cards = [
                    _MetricCard(
                      icon: Icons.grade_rounded,
                      label: 'Média geral',
                      value: '8,2',
                      caption: '+0,4 neste semestre',
                      accent: AppColors.gold,
                    ),
                    _MetricCard(
                      icon: Icons.done_all_rounded,
                      label: 'Atividades',
                      value: '${state.tasks.where((e) => e.status == TaskStatus.done).length}/${state.tasks.length}',
                      caption: '${state.pendingCount} ainda pendentes',
                    ),
                    const _MetricCard(
                      icon: Icons.event_available_rounded,
                      label: 'Frequência',
                      value: '89,8%',
                      caption: 'Acima do mínimo',
                    ),
                  ];
                  if (wide) {
                    return Row(
                      children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          Expanded(child: cards[i]),
                          if (i != cards.length - 1) const SizedBox(width: 12),
                        ]
                      ],
                    );
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        cards[i],
                        if (i != cards.length - 1) const SizedBox(height: 10),
                      ]
                    ],
                  );
                },
              ),
              const SizedBox(height: 26),
              const SectionTitle('Acesso rápido'),
              const SizedBox(height: 12),
              _QuickActions(state: state),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 850;
                  final deadlines = _Deadlines(tasks: pending.take(4).toList());
                  const progress = _SemesterProgress();
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: deadlines),
                        const SizedBox(width: 16),
                        const Expanded(flex: 2, child: progress),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      deadlines,
                      const SizedBox(height: 16),
                      progress,
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              const SectionTitle('Matérias em foco'),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth > 950 ? 3 : constraints.maxWidth > 620 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: cols == 1 ? 2.5 : 1.75,
                    ),
                    itemBuilder: (_, i) {
                      final s = subjects[i];
                      return SoftCard(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: s.color.withValues(alpha: .15),
                              child: Icon(s.icon, color: s.color),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(s.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 7),
                                  Row(
                                    children: [
                                      Text('Média ${s.grade.toStringAsFixed(1)}',
                                          style: Theme.of(context).textTheme.bodySmall),
                                      const SizedBox(width: 8),
                                      const Text('•'),
                                      const SizedBox(width: 8),
                                      Text('${s.attendance}% freq.',
                                          style: Theme.of(context).textTheme.bodySmall),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 20 : 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.petroleum,
            const Color(0xFF123A44),
            AppColors.petroleumDark.withValues(alpha: .96),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.gold.withValues(alpha: .18)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -55,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: .07),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GoldBadge('SEMESTRE 2026.2'),
              const SizedBox(height: 16),
              Text(
                'Olá, Victor! 👋',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: compact ? 25 : 32,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Sua próxima entrega é amanhã. Você está com o semestre sob controle.',
                style: TextStyle(color: Color(0xFFD5E2E5), height: 1.5),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _heroChip(Icons.timer_outlined, '1 dia para o próximo prazo'),
                  _heroChip(Icons.local_fire_department_outlined, '7 dias de sequência'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 2),
          Icon(icon, color: AppColors.gold, size: 16),
          const SizedBox(width: 7),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (accent ?? Theme.of(context).colorScheme.primary)
                  .withValues(alpha: .11),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent ?? Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                Text(caption,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.add_task_rounded, 'Adicionar atividade', () => _showAddTask(context)),
      (Icons.note_add_outlined, 'Nova anotação', () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anotação rápida criada no protótipo.')),
        );
      }),
      (Icons.today_rounded, 'Horário do dia', () => state.setIndex(4)),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in actions)
          FilledButton.tonalIcon(
            onPressed: a.$3,
            icon: Icon(a.$1),
            label: Text(a.$2),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )
      ],
    );
  }

  void _showAddTask(BuildContext context) {
    final title = TextEditingController();
    String subject = subjects.first.name;
    Priority priority = Priority.medium;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Nova atividade'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: subject,
                  decoration: const InputDecoration(labelText: 'Matéria'),
                  items: subjects
                      .map((e) => DropdownMenuItem(value: e.name, child: Text(e.name)))
                      .toList(),
                  onChanged: (v) => setLocal(() => subject = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<Priority>(
                  initialValue: priority,
                  decoration: const InputDecoration(labelText: 'Prioridade'),
                  items: const [
                    DropdownMenuItem(value: Priority.high, child: Text('Alta')),
                    DropdownMenuItem(value: Priority.medium, child: Text('Média')),
                    DropdownMenuItem(value: Priority.low, child: Text('Baixa')),
                  ],
                  onChanged: (v) => setLocal(() => priority = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty) return;
                state.addTask(
                  AcademicTask(
                    id: DateTime.now().millisecondsSinceEpoch,
                    title: title.text.trim(),
                    subject: subject,
                    dueDate: DateTime.now().add(const Duration(days: 7)),
                    priority: priority,
                    status: TaskStatus.todo,
                  ),
                );
                Navigator.pop(context);
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Deadlines extends StatelessWidget {
  const _Deadlines({required this.tasks});
  final List<AcademicTask> tasks;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        children: [
          const SectionTitle('Próximos prazos', trailing: GoldBadge('7 DIAS')),
          const SizedBox(height: 10),
          for (var i = 0; i < tasks.length; i++) ...[
            _DeadlineRow(task: tasks[i]),
            if (i != tasks.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({required this.task});
  final AcademicTask task;

  @override
  Widget build(BuildContext context) {
    final days = task.dueDate.difference(DateTime.now()).inDays + 1;
    return Row(
      children: [
        Container(
          width: 46,
          height: 48,
          decoration: BoxDecoration(
            color: days <= 2
                ? AppColors.danger.withValues(alpha: .10)
                : Theme.of(context).colorScheme.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            days <= 1 ? 'AMANHÃ' : '${days}d',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: days <= 1 ? 9 : 13,
              fontWeight: FontWeight.w900,
              color: days <= 2 ? AppColors.danger : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(task.subject, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        const SizedBox(width: 8),
        GoldBadge(task.priority == Priority.high ? 'ALTA' : task.priority == Priority.medium ? 'MÉDIA' : 'BAIXA'),
      ],
    );
  }
}

class _SemesterProgress extends StatelessWidget {
  const _SemesterProgress();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Progresso do semestre'),
          const SizedBox(height: 18),
          const Center(child: MetricRing(value: .42, label: 'concluído', size: 116)),
          const SizedBox(height: 20),
          _progress(context, 'Atividades concluídas', .68),
          const SizedBox(height: 12),
          _progress(context, 'Conteúdos revisados', .54),
          const SizedBox(height: 12),
          _progress(context, 'Presença média', .90),
        ],
      ),
    );
  }

  Widget _progress(BuildContext context, String label, double value) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.bodySmall)),
            Text('${(value * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          minHeight: 7,
          borderRadius: BorderRadius.circular(20),
        ),
      ],
    );
  }
}
