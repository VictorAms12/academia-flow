import 'package:flutter/material.dart';

import '../models/attachment.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/v22_actions.dart';
import 'attachment_manager_screen.dart';

class SubjectDetailScreen extends StatefulWidget {
  const SubjectDetailScreen({super.key, required this.subjectId});
  final int subjectId;

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final subject = state.subjectById(widget.subjectId);
    if (subject == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Matéria')),
        body: const Center(child: Text('Esta matéria não existe mais.')),
      );
    }
    final avg = state.averageForSubject(subject.id!);
    return Scaffold(
      appBar: AppBar(
        title: Text(subject.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(onPressed: () => showSubjectEditor(context, state, subject: subject), icon: const Icon(Icons.edit_outlined)),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 3, 16, 11),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: SoftCard(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final compact = c.maxWidth < 650;
                      final identity = Row(children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(16)),
                          child: const Icon(Icons.auto_stories_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(subject.professor.isEmpty ? 'Professor não informado' : subject.professor, style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text(subject.room.isEmpty ? 'Local não informado' : subject.room, style: Theme.of(context).textTheme.bodySmall),
                        ])),
                      ]);
                      final metrics = Row(mainAxisSize: MainAxisSize.min, children: [
                        _Metric(label: 'Média', value: avg == null ? '—' : avg.toStringAsFixed(1)),
                        const SizedBox(width: 22),
                        _Metric(label: 'Frequência', value: '${subject.attendance.toStringAsFixed(0)}%'),
                        const SizedBox(width: 22),
                        _Metric(label: 'Faltas', value: '${subject.absences}'),
                      ]);
                      return compact
                          ? Column(children: [identity, const SizedBox(height: 15), Align(alignment: Alignment.centerLeft, child: metrics)])
                          : Row(children: [Expanded(child: identity), metrics]);
                    },
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: TabBar(
                controller: tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Aulas'),
                  Tab(text: 'Atividades & Provas'),
                  Tab(text: 'Notas'),
                  Tab(text: 'Materiais & Anotações'),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: TabBarView(
                  controller: tabs,
                  children: [
                    _ClassesTab(state: state, subject: subject),
                    _TasksTab(state: state, subject: subject),
                    _GradesTab(state: state, subject: subject),
                    _ResourcesTab(state: state, subject: subject),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 10)),
      ]);
}

class _ClassesTab extends StatelessWidget {
  const _ClassesTab({required this.state, required this.subject});
  final AppState state;
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final schedules = state.schedulesForSubject(subject.id!);
    final target = state.attendanceTarget(subject);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle('Rotina de aulas', trailing: IconButton.filledTonal(onPressed: () => showScheduleEditor(context, state, presetSubjectId: subject.id), icon: const Icon(Icons.add_rounded))),
        const SizedBox(height: 11),
        if (schedules.isEmpty)
          EmptyState(
            icon: Icons.schedule_rounded,
            title: 'Nenhum horário cadastrado',
            message: 'Adicione os dias e horários em que essa matéria acontece.',
            actionLabel: 'Adicionar horário',
            onAction: () => showScheduleEditor(context, state, presetSubjectId: subject.id),
          )
        else
          for (final entry in schedules)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SoftCard(
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(13)),
                    child: Text(dayName(entry.day).substring(0, 3).toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${entry.start} – ${entry.end}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${entry.classCount} aula${entry.classCount == 1 ? '' : 's'} • ${entry.room.isEmpty ? 'Local não informado' : entry.room}', style: Theme.of(context).textTheme.bodySmall),
                  ])),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') await showScheduleEditor(context, state, entry: entry);
                      if (value == 'delete' && await confirmDelete(context, 'horário de ${dayName(entry.day)}')) await state.deleteSchedule(entry);
                    },
                    itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Excluir'))],
                  ),
                ]),
              ),
            ),
        const SizedBox(height: 17),
        const SectionTitle('Frequência'),
        const SizedBox(height: 10),
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('${subject.attendance.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900))),
              GoldBadge('${subject.absences} FALTA${subject.absences == 1 ? '' : 'S'}'),
            ]),
            const SizedBox(height: 9),
            LinearProgressIndicator(value: subject.attendance / 100, minHeight: 8, borderRadius: BorderRadius.circular(20), color: subject.attendance < target ? AppColors.danger : AppColors.success),
            const SizedBox(height: 9),
            Text(
              subject.totalClasses == 0
                  ? 'Ainda não há aulas contabilizadas. Edite a matéria para informar aulas dadas e faltas.'
                  : '${subject.totalClasses} aulas contabilizadas • mínimo configurado: ${target.toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: () => showSubjectEditor(context, state, subject: subject), icon: const Icon(Icons.edit_calendar_outlined), label: const Text('Atualizar aulas e faltas')),
          ]),
        ),
      ],
    );
  }
}

class _TasksTab extends StatelessWidget {
  const _TasksTab({required this.state, required this.subject});
  final AppState state;
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final tasks = state.tasksForSubject(subject.id!);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle('Atividades & Provas', trailing: IconButton.filledTonal(onPressed: () => showTaskEditor(context, state, presetSubjectId: subject.id), icon: const Icon(Icons.add_rounded))),
        const SizedBox(height: 11),
        if (tasks.isEmpty)
          EmptyState(
            icon: Icons.assignment_outlined,
            title: 'Nenhum prazo nesta matéria',
            message: 'Cadastre atividades, provas, seminários, projetos, leituras e outros prazos relacionados à disciplina.',
            actionLabel: 'Adicionar prazo',
            onAction: () => showTaskEditor(context, state, presetSubjectId: subject.id),
          )
        else
          for (final task in tasks) Padding(padding: const EdgeInsets.only(bottom: 9), child: _SubjectTaskCard(state: state, task: task)),
      ],
    );
  }
}

class _SubjectTaskCard extends StatelessWidget {
  const _SubjectTaskCard({required this.state, required this.task});
  final AppState state;
  final AcademicTask task;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
          if (task.id != null)
            IconButton(
              tooltip: 'Anexos',
              onPressed: () => showAttachmentManager(
                context,
                target: AttachmentTarget(type: AttachmentTargetType.task, id: task.id!, subjectId: task.subjectId),
                title: task.title,
              ),
              icon: const Icon(Icons.attach_file_rounded),
            ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') await showTaskEditor(context, state, task: task);
              if (value == 'attachments' && task.id != null) {
                await showAttachmentManager(
                  context,
                  target: AttachmentTarget(type: AttachmentTargetType.task, id: task.id!, subjectId: task.subjectId),
                  title: task.title,
                );
              }
              if (value == 'delete' && await confirmDelete(context, task.title)) await state.deleteTask(task);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
              if (task.id != null) const PopupMenuItem(value: 'attachments', child: Text('Anexos')),
              const PopupMenuItem(value: 'delete', child: Text('Excluir')),
            ],
          ),
        ]),
        Wrap(spacing: 7, runSpacing: 7, children: [
          GoldBadge(taskKindLabel(task.kind).toUpperCase()),
          GoldBadge(formatDate(task.dueDate)),
          GoldBadge(task.status == TaskStatus.done ? 'CONCLUÍDO' : task.status == TaskStatus.doing ? 'EM ANDAMENTO' : 'A FAZER'),
        ]),
        if (task.description.isNotEmpty) ...[
          const SizedBox(height: 11),
          Text(task.description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
        ],
        if (task.checklist.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 4),
          for (var i = 0; i < task.checklist.length; i++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: task.completedSteps.contains(i),
              title: Text(task.checklist[i]),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (_) => state.toggleTaskStep(task, i),
            ),
        ],
      ]),
    );
  }
}

class _GradesTab extends StatelessWidget {
  const _GradesTab({required this.state, required this.subject});
  final AppState state;
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final grades = state.gradesForSubject(subject.id!);
    final avg = state.averageForSubject(subject.id!);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle('Notas', trailing: IconButton.filledTonal(onPressed: () => showGradeEditor(context, state, presetSubjectId: subject.id), icon: const Icon(Icons.add_rounded))),
        const SizedBox(height: 11),
        SoftCard(
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(avg == null ? '—' : avg.toStringAsFixed(2), style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w900)),
              Text('Média ponderada atual', style: Theme.of(context).textTheme.bodySmall),
            ])),
            Icon(avg != null && avg < state.minGrade ? Icons.warning_amber_rounded : Icons.workspace_premium_outlined, color: avg != null && avg < state.minGrade ? AppColors.danger : AppColors.gold, size: 32),
          ]),
        ),
        const SizedBox(height: 11),
        if (grades.isEmpty)
          EmptyState(icon: Icons.grade_outlined, title: 'Nenhuma nota cadastrada', message: 'Adicione avaliações e seus pesos para calcular a média automaticamente.', actionLabel: 'Adicionar nota', onAction: () => showGradeEditor(context, state, presetSubjectId: subject.id))
        else
          for (final grade in grades)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SoftCard(
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: (grade.value < state.minGrade ? AppColors.danger : AppColors.gold).withValues(alpha: .10), borderRadius: BorderRadius.circular(13)),
                    child: Text(grade.value.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.w900, color: grade.value < state.minGrade ? AppColors.danger : AppColors.gold)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(grade.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text('${formatDate(grade.date)} • peso ${grade.weight.toStringAsFixed(1)}', style: Theme.of(context).textTheme.bodySmall),
                  ])),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') await showGradeEditor(context, state, grade: grade);
                      if (value == 'delete' && await confirmDelete(context, grade.title)) await state.deleteGrade(grade);
                    },
                    itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Excluir'))],
                  ),
                ]),
              ),
            ),
      ],
    );
  }
}

class _ResourcesTab extends StatelessWidget {
  const _ResourcesTab({required this.state, required this.subject});
  final AppState state;
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final notes = state.notesForSubject(subject.id!);
    final materials = state.materialsForSubject(subject.id!);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionTitle(
          'Materiais',
          trailing: IconButton.filledTonal(onPressed: () => showMaterialEditor(context, state, presetSubjectId: subject.id), icon: const Icon(Icons.add_rounded)),
        ),
        const SizedBox(height: 11),
        if (materials.isEmpty)
          Text('Nenhum material salvo nesta matéria.', style: Theme.of(context).textTheme.bodySmall)
        else
          for (final material in materials)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SoftCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(child: Icon(_materialIcon(material.kind))),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(material.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(materialKindLabel(material.kind), style: Theme.of(context).textTheme.bodySmall),
                    if (material.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(material.description, maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                    if (material.url.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      SelectableText(material.url, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
                    ],
                  ])),
                  if (material.id != null)
                    IconButton(
                      tooltip: 'Anexos',
                      onPressed: () => showAttachmentManager(
                        context,
                        target: AttachmentTarget(type: AttachmentTargetType.material, id: material.id!, subjectId: material.subjectId),
                        title: material.title,
                      ),
                      icon: const Icon(Icons.attach_file_rounded),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') await showMaterialEditor(context, state, material: material);
                      if (value == 'attachments' && material.id != null) {
                        await showAttachmentManager(
                          context,
                          target: AttachmentTarget(type: AttachmentTargetType.material, id: material.id!, subjectId: material.subjectId),
                          title: material.title,
                        );
                      }
                      if (value == 'delete' && await confirmDelete(context, material.title)) await state.deleteMaterial(material);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      if (material.id != null) const PopupMenuItem(value: 'attachments', child: Text('Anexos')),
                      const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                ]),
              ),
            ),
        const SizedBox(height: 18),
        SectionTitle(
          'Anotações',
          trailing: IconButton.filledTonal(onPressed: () => showNoteEditor(context, state, presetSubjectId: subject.id), icon: const Icon(Icons.note_add_outlined)),
        ),
        const SizedBox(height: 11),
        if (notes.isEmpty)
          Text('Nenhuma anotação salva nesta matéria.', style: Theme.of(context).textTheme.bodySmall)
        else
          for (final note in notes)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SoftCard(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  CircleAvatar(child: Icon(note.link.isEmpty ? Icons.notes_rounded : Icons.link_rounded)),
                  const SizedBox(width: 11),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      if (note.pinned) ...[const Icon(Icons.push_pin_rounded, size: 15, color: AppColors.gold), const SizedBox(width: 5)],
                      Expanded(child: Text(note.title, style: const TextStyle(fontWeight: FontWeight.w900))),
                    ]),
                    if (note.content.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(note.content, maxLines: 4, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(note.tags, style: Theme.of(context).textTheme.bodySmall),
                    ],
                    if (note.link.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      SelectableText(note.link, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
                    ],
                  ])),
                  if (note.id != null)
                    IconButton(
                      tooltip: 'Anexos',
                      onPressed: () => showAttachmentManager(
                        context,
                        target: AttachmentTarget(type: AttachmentTargetType.note, id: note.id!, subjectId: note.subjectId),
                        title: note.title,
                      ),
                      icon: const Icon(Icons.attach_file_rounded),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') await showNoteEditor(context, state, note: note);
                      if (value == 'attachments' && note.id != null) {
                        await showAttachmentManager(
                          context,
                          target: AttachmentTarget(type: AttachmentTargetType.note, id: note.id!, subjectId: note.subjectId),
                          title: note.title,
                        );
                      }
                      if (value == 'delete' && await confirmDelete(context, note.title)) await state.deleteNote(note);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      if (note.id != null) const PopupMenuItem(value: 'attachments', child: Text('Anexos')),
                      const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                ]),
              ),
            ),
      ],
    );
  }
}

IconData _materialIcon(MaterialKind kind) => switch (kind) {
      MaterialKind.pdf => Icons.picture_as_pdf_outlined,
      MaterialKind.slides => Icons.slideshow_outlined,
      MaterialKind.video => Icons.play_circle_outline_rounded,
      MaterialKind.repository => Icons.code_rounded,
      MaterialKind.document => Icons.description_outlined,
      MaterialKind.link => Icons.link_rounded,
      MaterialKind.other => Icons.attach_file_rounded,
    };
