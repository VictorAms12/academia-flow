import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';

Future<void> showSubjectEditor(
  BuildContext context,
  AppState state, {
  Subject? subject,
}) async {
  final name = TextEditingController(text: subject?.name ?? '');
  final professor = TextEditingController(text: subject?.professor ?? '');
  final room = TextEditingController(text: subject?.room ?? '');
  final totalClasses = TextEditingController(text: (subject?.totalClasses ?? 0).toString());
  final absences = TextEditingController(text: (subject?.absences ?? 0).toString());
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(subject == null ? 'Nova matéria' : 'Editar matéria'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nome da matéria *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome da matéria' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: professor, decoration: const InputDecoration(labelText: 'Professor(a)')),
                const SizedBox(height: 12),
                TextFormField(controller: room, decoration: const InputDecoration(labelText: 'Sala / local / link')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: totalClasses,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Aulas dadas'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: absences,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Faltas'),
                      ),
                    ),
                  ],
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
            final total = int.tryParse(totalClasses.text.trim()) ?? 0;
            final misses = int.tryParse(absences.text.trim()) ?? 0;
            if (misses > total && total > 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('O número de faltas não pode ser maior que as aulas dadas.')),
              );
              return;
            }
            await state.saveSubject(
              Subject(
                id: subject?.id,
                name: name.text.trim(),
                professor: professor.text.trim(),
                room: room.text.trim(),
                totalClasses: total.clamp(0, 9999).toInt(),
                absences: misses.clamp(0, 9999).toInt(),
              ),
            );
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}

Future<void> showTaskEditor(
  BuildContext context,
  AppState state, {
  AcademicTask? task,
  int? presetSubjectId,
}) async {
  final title = TextEditingController(text: task?.title ?? '');
  final description = TextEditingController(text: task?.description ?? '');
  final checklist = TextEditingController(text: task?.checklist.join('\n') ?? '');
  final formKey = GlobalKey<FormState>();
  int? subjectId = task?.subjectId ?? presetSubjectId;
  Priority priority = task?.priority ?? Priority.medium;
  TaskStatus status = task?.status ?? TaskStatus.todo;
  DateTime dueDate = task?.dueDate ?? DateTime.now().add(const Duration(days: 7));

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(task == null ? 'Nova atividade' : 'Editar atividade'),
        content: SizedBox(
          width: 520,
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: subjectId,
                    decoration: const InputDecoration(labelText: 'Matéria'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Sem matéria')),
                      ...state.subjects.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) => setLocal(() => subjectId = v),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<Priority>(
                          initialValue: priority,
                          decoration: const InputDecoration(labelText: 'Prioridade'),
                          items: const [
                            DropdownMenuItem(value: Priority.high, child: Text('Alta')),
                            DropdownMenuItem(value: Priority.medium, child: Text('Média')),
                            DropdownMenuItem(value: Priority.low, child: Text('Baixa')),
                          ],
                          onChanged: (v) => setLocal(() => priority = v ?? Priority.medium),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<TaskStatus>(
                          initialValue: status,
                          decoration: const InputDecoration(labelText: 'Status'),
                          items: const [
                            DropdownMenuItem(value: TaskStatus.todo, child: Text('A fazer')),
                            DropdownMenuItem(value: TaskStatus.doing, child: Text('Em andamento')),
                            DropdownMenuItem(value: TaskStatus.done, child: Text('Concluído')),
                          ],
                          onChanged: (v) => setLocal(() => status = v ?? TaskStatus.todo),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
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
                      child: Text('${dueDate.day.toString().padLeft(2, '0')}/${dueDate.month.toString().padLeft(2, '0')}/${dueDate.year}'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: description,
                    minLines: 3,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Orientações / descrição'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: checklist,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'Checklist',
                      hintText: 'Uma etapa por linha',
                    ),
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
              final steps = checklist.text
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              final completed = task?.completedSteps.where((i) => i < steps.length).toList() ?? <int>[];
              await state.saveTask(
                AcademicTask(
                  id: task?.id,
                  title: title.text.trim(),
                  subjectId: subjectId,
                  dueDate: dueDate,
                  priority: priority,
                  status: status,
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

Future<void> showGradeEditor(
  BuildContext context,
  AppState state, {
  Grade? grade,
  int? presetSubjectId,
}) async {
  if (state.subjects.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre uma matéria antes de adicionar notas.')));
    return;
  }
  int subjectId = grade?.subjectId ?? presetSubjectId ?? state.subjects.first.id!;
  final title = TextEditingController(text: grade?.title ?? '');
  final value = TextEditingController(text: grade?.value.toStringAsFixed(1).replaceAll('.', ',') ?? '');
  final weight = TextEditingController(text: grade?.weight.toString().replaceAll('.', ',') ?? '1');
  DateTime date = grade?.date ?? DateTime.now();
  final formKey = GlobalKey<FormState>();

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(grade == null ? 'Nova nota' : 'Editar nota'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: subjectId,
                    decoration: const InputDecoration(labelText: 'Matéria'),
                    items: state.subjects.map((s) => DropdownMenuItem(value: s.id!, child: Text(s.name))).toList(),
                    onChanged: (v) => setLocal(() => subjectId = v ?? subjectId),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Avaliação *', hintText: 'Ex.: Prova 1'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome da avaliação' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: value,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Nota (0–10) *'),
                          validator: (v) {
                            final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                            if (n == null || n < 0 || n > 10) return 'Use uma nota entre 0 e 10';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: weight,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Peso'),
                          validator: (v) {
                            final n = double.tryParse((v ?? '').replaceAll(',', '.'));
                            return n == null || n <= 0 ? 'Peso inválido' : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null) setLocal(() => date = selected);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Data'),
                      child: Text('${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'),
                    ),
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
              await state.saveGrade(
                Grade(
                  id: grade?.id,
                  subjectId: subjectId,
                  title: title.text.trim(),
                  value: double.parse(value.text.replaceAll(',', '.')),
                  weight: double.parse(weight.text.replaceAll(',', '.')),
                  date: date,
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

Future<void> showScheduleEditor(
  BuildContext context,
  AppState state, {
  ScheduleEntry? entry,
  int? presetSubjectId,
}) async {
  if (state.subjects.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre uma matéria antes de adicionar horários.')));
    return;
  }
  int subjectId = entry?.subjectId ?? presetSubjectId ?? state.subjects.first.id!;
  int day = entry?.day ?? DateTime.now().weekday.clamp(1, 5).toInt();
  TimeOfDay start = _parseTime(entry?.start ?? '19:00');
  TimeOfDay end = _parseTime(entry?.end ?? '20:40');
  final room = TextEditingController(text: entry?.room ?? state.subjectById(subjectId)?.room ?? '');

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(entry == null ? 'Novo horário' : 'Editar horário'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: subjectId,
                  decoration: const InputDecoration(labelText: 'Matéria'),
                  items: state.subjects.map((s) => DropdownMenuItem(value: s.id!, child: Text(s.name))).toList(),
                  onChanged: (v) => setLocal(() {
                    subjectId = v ?? subjectId;
                    if (room.text.trim().isEmpty) room.text = state.subjectById(subjectId)?.room ?? '';
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: day,
                  decoration: const InputDecoration(labelText: 'Dia da semana'),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Segunda-feira')),
                    DropdownMenuItem(value: 2, child: Text('Terça-feira')),
                    DropdownMenuItem(value: 3, child: Text('Quarta-feira')),
                    DropdownMenuItem(value: 4, child: Text('Quinta-feira')),
                    DropdownMenuItem(value: 5, child: Text('Sexta-feira')),
                    DropdownMenuItem(value: 6, child: Text('Sábado')),
                    DropdownMenuItem(value: 7, child: Text('Domingo')),
                  ],
                  onChanged: (v) => setLocal(() => day = v ?? day),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _TimeField(
                        label: 'Início',
                        time: start,
                        onTap: () async {
                          final selected = await showTimePicker(context: context, initialTime: start);
                          if (selected != null) setLocal(() => start = selected);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TimeField(
                        label: 'Fim',
                        time: end,
                        onTap: () async {
                          final selected = await showTimePicker(context: context, initialTime: end);
                          if (selected != null) setLocal(() => end = selected);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(controller: room, decoration: const InputDecoration(labelText: 'Sala / local')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              await state.saveSchedule(
                ScheduleEntry(
                  id: entry?.id,
                  subjectId: subjectId,
                  day: day,
                  start: _formatTime(start),
                  end: _formatTime(end),
                  room: room.text.trim(),
                  classCount: entry?.classCount ?? 1,
                  reminderMinutes: entry?.reminderMinutes ?? 10,
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

Future<void> showNoteEditor(
  BuildContext context,
  AppState state, {
  AcademicNote? note,
  int? presetSubjectId,
}) async {
  final title = TextEditingController(text: note?.title ?? '');
  final content = TextEditingController(text: note?.content ?? '');
  final link = TextEditingController(text: note?.link ?? '');
  final formKey = GlobalKey<FormState>();
  int? subjectId = note?.subjectId ?? presetSubjectId;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: Text(note == null ? 'Nova anotação / material' : 'Editar anotação'),
        content: SizedBox(
          width: 520,
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
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: subjectId,
                    decoration: const InputDecoration(labelText: 'Matéria'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Geral / sem matéria')),
                      ...state.subjects.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name))),
                    ],
                    onChanged: (v) => setLocal(() => subjectId = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: content,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(labelText: 'Anotação / descrição'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: link,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(labelText: 'Link do material (opcional)'),
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
              await state.saveNote(
                AcademicNote(
                  id: note?.id,
                  subjectId: subjectId,
                  title: title.text.trim(),
                  content: content.text.trim(),
                  link: link.text.trim(),
                  createdAt: note?.createdAt ?? DateTime.now(),
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

Future<bool> confirmDelete(BuildContext context, String itemName) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Excluir?'),
          content: Text('“$itemName” será removido do aplicativo. Esta ação não pode ser desfeita.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Excluir'),
            ),
          ],
        ),
      ) ??
      false;
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts.first) ?? 19,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

String _formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.time, required this.onTap});
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(_formatTime(time)),
      ),
    );
  }
}
