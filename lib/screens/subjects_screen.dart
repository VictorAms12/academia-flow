import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';
import '../widgets/motion.dart';
import 'subject_detail_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final filtered = state.subjects.where((s) => s.name.toLowerCase().contains(search.toLowerCase())).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Matérias',
                subtitle: 'Gerencie disciplinas, notas, faltas, tarefas e materiais.',
                action: FilledButton.icon(
                  onPressed: () => showSubjectEditor(context, state),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Adicionar'),
                ),
              ),
              const SizedBox(height: 17),
              if (state.subjects.isNotEmpty) ...[
                MotionEntrance(
                  delay: const Duration(milliseconds: 60),
                  child: TextField(
                    onChanged: (v) => setState(() => search = v),
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar matéria...'),
                  ),
                ),
                const SizedBox(height: 17),
              ],
              if (state.subjects.isEmpty)
                EmptyState(
                  icon: Icons.auto_stories_rounded,
                  title: 'Nenhuma matéria cadastrada',
                  message: 'Adicione as disciplinas do semestre para começar a acompanhar notas, frequência, horários e atividades.',
                  actionLabel: 'Cadastrar matéria',
                  onAction: () => showSubjectEditor(context, state),
                )
              else if (filtered.isEmpty)
                const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'Nenhum resultado',
                  message: 'Não encontramos uma matéria com esse nome.',
                )
              else
                LayoutBuilder(
                  builder: (context, c) {
                    final cols = c.maxWidth >= 970 ? 3 : c.maxWidth >= 620 ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        crossAxisSpacing: 13,
                        mainAxisSpacing: 13,
                        childAspectRatio: cols == 1 ? 1.8 : 1.14,
                      ),
                      itemBuilder: (_, i) => MotionEntrance(
                        key: ValueKey(filtered[i].id ?? filtered[i].name),
                        delay: Duration(milliseconds: (i.clamp(0, 7)) * 38),
                        offset: const Offset(0, .06),
                        child: _SubjectCard(state: state, subject: filtered[i]),
                      ),
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

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.state, required this.subject});
  final AppState state;
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final avg = subject.id == null ? null : state.averageForSubject(subject.id!);
    final risk = state.isSubjectAtRisk(subject);
    final pending = subject.id == null ? 0 : state.tasksForSubject(subject.id!).where((e) => e.status != TaskStatus.done).length;

    return SoftCard(
      onTap: () => Navigator.of(context).push(
        motionRoute(SubjectDetailScreen(subjectId: subject.id!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'subject-icon-${subject.id}',
                child: Container(
                  width: 49,
                  height: 49,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.auto_stories_rounded),
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: MotionSpec.fast,
                child: risk
                    ? Container(
                        key: const ValueKey('risk'),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)),
                        child: const Text('ATENÇÃO', style: TextStyle(color: AppColors.danger, fontSize: 9, fontWeight: FontWeight.w900)),
                      )
                    : const GoldBadge('ATIVA', key: ValueKey('active')),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'edit') {
                    await showSubjectEditor(context, state, subject: subject);
                  } else if (value == 'delete') {
                    if (await confirmDelete(context, subject.name)) await state.deleteSubject(subject);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Editar'))),
                  PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Excluir'))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(subject.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(subject.professor.isEmpty ? 'Professor não informado' : subject.professor, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14),
              const SizedBox(width: 4),
              Expanded(child: Text(subject.room.isEmpty ? 'Local não informado' : subject.room, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(child: _Stat(label: 'Média', value: avg == null ? '—' : avg.toStringAsFixed(1))),
              Container(width: 1, height: 34, color: Theme.of(context).dividerColor),
              Expanded(child: _Stat(label: 'Frequência', value: '${subject.attendance.toStringAsFixed(0)}%')),
              Container(width: 1, height: 34, color: Theme.of(context).dividerColor),
              Expanded(child: _Stat(label: 'Pendentes', value: '$pending')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: MotionSpec.fast,
          child: Text(value, key: ValueKey(value), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
