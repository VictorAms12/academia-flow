import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'forms.dart' as legacy;

Future<void> showSubjectEditor(BuildContext context, AppState state, {Subject? subject}) =>
    legacy.showSubjectEditor(context, state, subject: subject);
Future<void> showGradeEditor(BuildContext context, AppState state, {Grade? grade, int? presetSubjectId}) =>
    legacy.showGradeEditor(context, state, grade: grade, presetSubjectId: presetSubjectId);
Future<void> showScheduleEditor(BuildContext context, AppState state, {ScheduleEntry? entry, int? presetSubjectId}) =>
    legacy.showScheduleEditor(context, state, entry: entry, presetSubjectId: presetSubjectId);
Future<bool> confirmDelete(BuildContext context, String itemName) => legacy.confirmDelete(context, itemName);

Future<void> showTaskEditor(
  BuildContext context,
  AppState state, {
  AcademicTask? task,
  int? presetSubjectId,
  TaskKind? presetKind,
}) async {
  final title = TextEditingController(text: task?.title ?? '');
  final description = TextEditingController(text: task?.description ?? '');
  final checklist = TextEditingController(text: task?.checklist.join('\n') ?? '');
  final formKey = GlobalKey<FormState>();
  int? subjectId = task?.subjectId ?? presetSubjectId;
  Priority priority = task?.priority ?? Priority.medium;
  TaskStatus status = task?.status ?? TaskStatus.todo;
  TaskKind kind = task?.kind ?? presetKind ?? TaskKind.activity;
  bool reminders = task?.reminderEnabled ?? true;
  DateTime dueDate = task?.dueDate ?? DateTime.now().add(const Duration(days: 7));

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(task == null ? 'Novo prazo' : 'Editar prazo'),
        content: SizedBox(
          width: 540,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: title,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Título *'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Informe o título' : null,
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<TaskKind>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: TaskKind.values.map((e) => DropdownMenuItem(value: e, child: Text(taskKindLabel(e)))).toList(),
                    onChanged: (v) => setLocal(() => kind = v ?? kind),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    initialValue: subjectId,
                    decoration: const InputDecoration(labelText: 'Matéria'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Sem matéria')),
                      ...state.subjects.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) => setLocal(() => subjectId = v),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField<Priority>(
                        initialValue: priority,
                        decoration: const InputDecoration(labelText: 'Prioridade'),
                        items: const [
                          DropdownMenuItem(value: Priority.high, child: Text('Alta')),
                          DropdownMenuItem(value: Priority.medium, child: Text('Média')),
                          DropdownMenuItem(value: Priority.low, child: Text('Baixa')),
                        ],
                        onChanged: (v) => setLocal(() => priority = v ?? priority),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<TaskStatus>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: TaskStatus.todo, child: Text('A fazer')),
                          DropdownMenuItem(value: TaskStatus.doing, child: Text('Em andamento')),
                          DropdownMenuItem(value: TaskStatus.done, child: Text('Concluído')),
                        ],
                        onChanged: (v) => setLocal(() => status = v ?? status),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null) setLocal(() => dueDate = selected);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Prazo'),
                      child: Text(_formatDate(dueDate)),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: reminders,
                    title: const Text('Lembretes automáticos'),
                    subtitle: const Text('7 dias, 3 dias, 1 dia e no dia do prazo'),
                    onChanged: (v) => setLocal(() => reminders = v),
                  ),
                  TextFormField(
                    controller: description,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Descrição / orientações'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: checklist,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Checklist', hintText: 'Uma etapa por linha'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final steps = checklist.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
              final completed = task?.completedSteps.where((i) => i < steps.length).toList() ?? <int>[];
              if (reminders) await state.notifications.requestPermission();
              await state.saveTask(
                AcademicTask(
                  id: task?.id,
                  title: title.text.trim(),
                  subjectId: subjectId,
                  dueDate: dueDate,
                  priority: priority,
                  status: status,
                  kind: kind,
                  reminderEnabled: reminders,
                  description: description.text.trim(),
                  checklist: steps,
                  completedSteps: completed,
                ),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showNoteEditor(BuildContext context, AppState state, {AcademicNote? note, int? presetSubjectId}) async {
  final title = TextEditingController(text: note?.title ?? '');
  final content = TextEditingController(text: note?.content ?? '');
  final link = TextEditingController(text: note?.link ?? '');
  final tags = TextEditingController(text: note?.tags ?? '');
  int? subjectId = note?.subjectId ?? presetSubjectId;
  bool pinned = note?.pinned ?? false;
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (dc) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(note == null ? 'Nova anotação' : 'Editar anotação'),
        content: SizedBox(
          width: 560,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Título *'), validator: (v) => v == null || v.trim().isEmpty ? 'Informe o título' : null),
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  initialValue: subjectId,
                  decoration: const InputDecoration(labelText: 'Matéria'),
                  items: [const DropdownMenuItem<int?>(value: null, child: Text('Geral')), ...state.subjects.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name)))],
                  onChanged: (v) => setLocal(() => subjectId = v),
                ),
                const SizedBox(height: 10),
                TextFormField(controller: content, minLines: 6, maxLines: 14, decoration: const InputDecoration(labelText: 'Conteúdo', hintText: 'Resumo, tópicos, fórmulas, checklist de revisão...')),
                const SizedBox(height: 10),
                TextFormField(controller: tags, decoration: const InputDecoration(labelText: 'Tags', hintText: 'prova, revisão, importante')),
                const SizedBox(height: 10),
                TextFormField(controller: link, decoration: const InputDecoration(labelText: 'Link relacionado')),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: pinned, title: const Text('Fixar anotação'), onChanged: (v) => setLocal(() => pinned = v)),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              await state.saveNote(AcademicNote(id: note?.id, subjectId: subjectId, title: title.text.trim(), content: content.text.trim(), link: link.text.trim(), tags: tags.text.trim(), pinned: pinned, createdAt: note?.createdAt ?? DateTime.now()));
              if (dc.mounted) Navigator.pop(dc);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showMaterialEditor(BuildContext context, AppState state, {MaterialResource? material, int? presetSubjectId}) async {
  if (state.subjects.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre uma matéria antes de adicionar materiais.')));
    return;
  }
  final title = TextEditingController(text: material?.title ?? '');
  final url = TextEditingController(text: material?.url ?? '');
  final description = TextEditingController(text: material?.description ?? '');
  int subjectId = material?.subjectId ?? presetSubjectId ?? state.subjects.first.id!;
  MaterialKind kind = material?.kind ?? MaterialKind.link;
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (dc) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(material == null ? 'Novo material' : 'Editar material'),
        content: SizedBox(
          width: 520,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Título *'), validator: (v) => v == null || v.trim().isEmpty ? 'Informe o título' : null),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(initialValue: subjectId, decoration: const InputDecoration(labelText: 'Matéria'), items: state.subjects.map((s) => DropdownMenuItem(value: s.id!, child: Text(s.name))).toList(), onChanged: (v) => setLocal(() => subjectId = v ?? subjectId)),
              const SizedBox(height: 10),
              DropdownButtonFormField<MaterialKind>(initialValue: kind, decoration: const InputDecoration(labelText: 'Tipo'), items: MaterialKind.values.map((e) => DropdownMenuItem(value: e, child: Text(materialKindLabel(e)))).toList(), onChanged: (v) => setLocal(() => kind = v ?? kind)),
              const SizedBox(height: 10),
              TextFormField(controller: url, decoration: const InputDecoration(labelText: 'Link / caminho', hintText: 'PDF, Drive, YouTube, GitHub, site...')),
              const SizedBox(height: 10),
              TextFormField(controller: description, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Descrição')),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              await state.saveMaterial(MaterialResource(id: material?.id, subjectId: subjectId, title: title.text.trim(), url: url.text.trim(), description: description.text.trim(), kind: kind, createdAt: material?.createdAt ?? DateTime.now()));
              if (dc.mounted) Navigator.pop(dc);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showGradeSimulator(BuildContext context, AppState state) async {
  if (state.subjects.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre uma matéria primeiro.')));
    return;
  }
  int subjectId = state.subjects.first.id!;
  final weight = TextEditingController(text: '1');
  double? result = state.requiredNextGrade(subjectId);
  await showDialog<void>(
    context: context,
    builder: (dc) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: const Text('Simulador de média'),
        content: SizedBox(
          width: 430,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(initialValue: subjectId, decoration: const InputDecoration(labelText: 'Matéria'), items: state.subjects.map((s) => DropdownMenuItem(value: s.id!, child: Text(s.name))).toList(), onChanged: (v) => setLocal(() { subjectId = v ?? subjectId; result = state.requiredNextGrade(subjectId, futureWeight: double.tryParse(weight.text.replaceAll(',', '.')) ?? 1); })),
            const SizedBox(height: 10),
            TextField(controller: weight, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Peso da próxima avaliação'), onChanged: (_) => setLocal(() => result = state.requiredNextGrade(subjectId, futureWeight: double.tryParse(weight.text.replaceAll(',', '.')) ?? 1))),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(16)),
              child: Column(children: [
                Text(result == null ? '—' : result! <= 0 ? 'Você já atingiu a meta' : result! > 10 ? 'Acima de 10' : result!.toStringAsFixed(2), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('Nota necessária para média ${state.minGrade.toStringAsFixed(1)}', textAlign: TextAlign.center),
              ]),
            ),
          ]),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Fechar'))],
      ),
    ),
  );
}

Future<void> showAttendancePlanner(BuildContext context, AppState state) async {
  if (state.subjects.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre uma matéria primeiro.')));
    return;
  }
  Subject selected = state.subjects.first;
  await showDialog<void>(
    context: context,
    builder: (dc) => StatefulBuilder(
      builder: (context, setLocal) {
        final remaining = state.remainingAbsences(selected);
        return AlertDialog(
          title: const Text('Controle de faltas'),
          content: SizedBox(
            width: 430,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<Subject>(initialValue: selected, decoration: const InputDecoration(labelText: 'Matéria'), items: state.subjects.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(), onChanged: (v) => setLocal(() => selected = v ?? selected)),
              const SizedBox(height: 16),
              ListTile(contentPadding: EdgeInsets.zero, title: Text('${selected.attendance.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)), subtitle: const Text('Frequência atual')),
              ListTile(contentPadding: EdgeInsets.zero, title: Text(selected.plannedClasses <= 0 ? 'Informe as aulas previstas' : remaining >= 9999 ? '—' : '$remaining', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), subtitle: const Text('Faltas que ainda cabem no limite configurado')),
              FilledButton.tonalIcon(
                onPressed: () async {
                  await state.saveSubject(selected.copyWith(absences: selected.absences + 1));
                  selected = state.subjectById(selected.id)!;
                  setLocal(() {});
                },
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text('Registrar +1 falta'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: () async { Navigator.pop(dc); await legacy.showSubjectEditor(context, state, subject: selected); }, icon: const Icon(Icons.edit_outlined), label: const Text('Editar aulas e faltas')),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dc), child: const Text('Fechar'))],
        );
      },
    ),
  );
}

Future<void> showQuickAddSheet(BuildContext context, AppState state) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('O que você quer adicionar?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _quick(sheet, Icons.assignment_outlined, 'Atividade', () => showTaskEditor(context, state, presetKind: TaskKind.activity)),
            _quick(sheet, Icons.quiz_outlined, 'Prova', () => showTaskEditor(context, state, presetKind: TaskKind.exam)),
            _quick(sheet, Icons.auto_stories_outlined, 'Matéria', () => legacy.showSubjectEditor(context, state)),
            _quick(sheet, Icons.grade_outlined, 'Nota', () => legacy.showGradeEditor(context, state)),
            _quick(sheet, Icons.event_busy_outlined, 'Falta', () => showAttendancePlanner(context, state)),
            _quick(sheet, Icons.schedule_outlined, 'Aula', () => legacy.showScheduleEditor(context, state)),
            _quick(sheet, Icons.note_add_outlined, 'Anotação', () => showNoteEditor(context, state)),
            _quick(sheet, Icons.attach_file_rounded, 'Material', () => showMaterialEditor(context, state)),
            _quick(sheet, Icons.calculate_outlined, 'Simular média', () => showGradeSimulator(context, state)),
          ]),
        ]),
      ),
    ),
  );
}

Widget _quick(BuildContext sheet, IconData icon, String label, Future<void> Function() action) => ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      onPressed: () async {
        Navigator.pop(sheet);
        await action();
      },
    );

String taskKindLabel(TaskKind kind) => switch (kind) {
      TaskKind.activity => 'Atividade',
      TaskKind.exam => 'Prova',
      TaskKind.seminar => 'Seminário',
      TaskKind.project => 'Projeto',
      TaskKind.reading => 'Leitura',
      TaskKind.other => 'Outro',
    };
String materialKindLabel(MaterialKind kind) => switch (kind) {
      MaterialKind.pdf => 'PDF',
      MaterialKind.slides => 'Slides',
      MaterialKind.video => 'Vídeo',
      MaterialKind.link => 'Link',
      MaterialKind.repository => 'Repositório',
      MaterialKind.document => 'Documento',
      MaterialKind.other => 'Outro',
    };
String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
