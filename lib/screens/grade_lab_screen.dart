import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/v22_actions.dart';

class GradeLabScreen extends StatefulWidget {
  const GradeLabScreen({super.key});

  @override
  State<GradeLabScreen> createState() => _GradeLabScreenState();
}

class _GradeLabScreenState extends State<GradeLabScreen> {
  double futureWeight = 1;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Notas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(
                    title: 'Laboratório de notas',
                    subtitle: 'Acompanhe médias e veja quanto precisa tirar na próxima avaliação.',
                    action: FilledButton.icon(
                      onPressed: state.subjects.isEmpty ? null : () => showGradeEditor(context, state),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Adicionar nota'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  SoftCard(
                    child: Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: AppColors.gold),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Peso da próxima avaliação', style: TextStyle(fontWeight: FontWeight.w900)),
                              Text('A projeção abaixo usa esse peso para todas as matérias.', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                        DropdownButton<double>(
                          value: futureWeight,
                          items: const <double>[0.5, 1.0, 1.5, 2.0, 3.0, 4.0, 5.0]
                              .map(
                                (value) => DropdownMenuItem<double>(
                                  value: value,
                                  child: Text(value.toStringAsFixed(value % 1 == 0 ? 0 : 1)),
                                ),
                              )
                              .toList(),
                          onChanged: (value) => setState(() => futureWeight = value ?? futureWeight),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (state.subjects.isEmpty)
                    const EmptyState(
                      icon: Icons.grade_outlined,
                      title: 'Sem matérias',
                      message: 'Cadastre matérias para começar a projetar suas médias.',
                    )
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 760) {
                          return Column(
                            children: [
                              for (var i = 0; i < state.subjects.length; i++) ...[
                                _SubjectGradeCard(
                                  state: state,
                                  subject: state.subjects[i],
                                  futureWeight: futureWeight,
                                ),
                                if (i < state.subjects.length - 1) const SizedBox(height: 10),
                              ],
                            ],
                          );
                        }

                        final width = (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final subject in state.subjects)
                              SizedBox(
                                width: width,
                                child: _SubjectGradeCard(
                                  state: state,
                                  subject: subject,
                                  futureWeight: futureWeight,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  if (state.subjects.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    SoftCard(
                      child: Row(
                        children: [
                          const Icon(Icons.calculate_outlined, color: AppColors.gold),
                          const SizedBox(width: 11),
                          const Expanded(
                            child: Text(
                              'Quer testar outro peso ou uma matéria específica?',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          TextButton(
                            onPressed: () => showGradeSimulator(context, state),
                            child: const Text('Abrir simulador'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectGradeCard extends StatelessWidget {
  const _SubjectGradeCard({
    required this.state,
    required this.subject,
    required this.futureWeight,
  });

  final AppState state;
  final Subject subject;
  final double futureWeight;

  @override
  Widget build(BuildContext context) {
    final grades = subject.id == null ? <Grade>[] : state.gradesForSubject(subject.id!);
    final average = subject.id == null ? null : state.averageForSubject(subject.id!);
    final required = subject.id == null
        ? null
        : state.requiredNextGrade(subject.id!, futureWeight: futureWeight);
    final examTasks = subject.id == null
        ? <AcademicTask>[]
        : state.tasks
            .where(
              (task) =>
                  task.subjectId == subject.id &&
                  task.kind == TaskKind.exam &&
                  task.status != TaskStatus.done,
            )
            .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final nextExam = examTasks.isEmpty ? null : examTasks.first;
    final atRisk = average != null && average < state.minGrade;

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              if (atRisk) const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                average?.toStringAsFixed(2) ?? '—',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: atRisk ? AppColors.danger : null,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text('média atual', style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRÓXIMA AVALIAÇÃO',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.gold),
                ),
                const SizedBox(height: 4),
                Text(
                  _requiredText(required),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                Text(
                  'para alcançar média ${state.minGrade.toStringAsFixed(1)} com peso ${futureWeight.toStringAsFixed(futureWeight % 1 == 0 ? 0 : 1)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${grades.length} nota${grades.length == 1 ? '' : 's'} registrada${grades.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (grades.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: grades
                  .take(4)
                  .map(
                    (grade) => Chip(
                      label: Text('${grade.title}: ${grade.value.toStringAsFixed(1)}'),
                      visualDensity: VisualDensity.compact,
                    ),
                  )
                  .toList(),
            ),
          ],
          if (nextExam != null) ...[
            const SizedBox(height: 10),
            const Divider(),
            Row(
              children: [
                const Icon(Icons.quiz_outlined, size: 17, color: AppColors.gold),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${nextExam.title} • ${_date(nextExam.dueDate)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _requiredText(double? value) {
  if (value == null) return 'Adicione notas para calcular';
  if (value <= 0) return 'Meta já alcançada';
  if (value > 10) return 'Precisaria de ${value.toStringAsFixed(1)}';
  return 'Precisa de ${value.toStringAsFixed(2)}';
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';
