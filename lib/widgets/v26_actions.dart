import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/v26_models.dart';
import '../state/app_state.dart';
import '../state/v26_controller.dart';

Future<void> showStudyBlockEditor(
  BuildContext context,
  AppState state, {
  StudyBlock? block,
  DateTime? initialDate,
}) async {
  final controller = V26Controller.instance..bind(state);
  await controller.initialize(state);
  if (!context.mounted) return;

  final title = TextEditingController(text: block?.title ?? '');
  final note = TextEditingController(text: block?.note ?? '');
  int? subjectId = block?.subjectId;
  var startsAt = block?.startsAt ?? _defaultStudyTime(initialDate ?? DateTime.now());
  var duration = block?.durationMinutes ?? 60;
  final formKey = GlobalKey<FormState>();

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(block == null ? 'Novo bloco de estudo' : 'Editar bloco de estudo'),
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
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'O que você vai estudar? *', prefixIcon: Icon(Icons.menu_book_rounded)),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Informe o foco do estudo' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int?>(
                      initialValue: subjectId,
                      decoration: const InputDecoration(labelText: 'Matéria'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Estudo geral')),
                        ...state.subjects.where((subject) => subject.id != null).map(
                              (subject) => DropdownMenuItem<int?>(value: subject.id, child: Text(subject.name)),
                            ),
                      ],
                      onChanged: (value) => setLocal(() => subjectId = value),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final selected = await showDatePicker(
                                context: context,
                                initialDate: startsAt,
                                firstDate: DateTime(2024),
                                lastDate: DateTime(2100),
                              );
                              if (selected == null) return;
                              setLocal(() => startsAt = DateTime(selected.year, selected.month, selected.day, startsAt.hour, startsAt.minute));
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Data'),
                              child: Text(_dateLabel(startsAt)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              final selected = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.fromDateTime(startsAt),
                              );
                              if (selected == null) return;
                              setLocal(() => startsAt = DateTime(startsAt.year, startsAt.month, startsAt.day, selected.hour, selected.minute));
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(labelText: 'Horário'),
                              child: Text(_timeLabel(startsAt)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: duration,
                      decoration: const InputDecoration(labelText: 'Duração estimada'),
                      items: const [30, 45, 60, 90, 120, 180]
                          .map((minutes) => DropdownMenuItem(value: minutes, child: Text(compactDuration(minutes))))
                          .toList(),
                      onChanged: (value) => setLocal(() => duration = value ?? duration),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: note,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(labelText: 'Objetivo / observação', hintText: 'Ex.: revisar JOIN e resolver os exercícios 4–8'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton.icon(
              onPressed: () async {
                if (!(formKey.currentState?.validate() ?? false)) return;
                await controller.saveStudyBlock(
                  existing: block,
                  title: title.text,
                  startsAt: startsAt,
                  subjectId: subjectId,
                  durationMinutes: duration,
                  note: note.text,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              icon: const Icon(Icons.check_rounded),
              label: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  } finally {
    title.dispose();
    note.dispose();
  }
}

Future<void> showQuickClassNote(BuildContext context, AppState state, ClassSession session) async {
  final controller = V26Controller.instance..bind(state);
  final content = TextEditingController();
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(18, 4, 18, 18 + MediaQuery.viewInsetsOf(sheetContext).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nota rápida • ${state.subjectName(session.subjectId)}', style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text('${_dateLabel(session.date)} • ${session.start}–${session.end}', style: Theme.of(sheetContext).textTheme.bodySmall),
            const SizedBox(height: 14),
            TextField(
              controller: content,
              autofocus: true,
              minLines: 4,
              maxLines: 10,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Conceito importante, dúvida, exercício, recado do professor...'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  if (content.text.trim().isEmpty) return;
                  await controller.saveQuickClassNote(session, content.text);
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nota salva e vinculada à aula.')));
                  }
                },
                icon: const Icon(Icons.note_add_rounded),
                label: const Text('Salvar nota rápida'),
              ),
            ),
          ],
        ),
      ),
    );
  } finally {
    content.dispose();
  }
}

Future<void> showAttendanceEditor(BuildContext context, AppState state, ClassSession session) async {
  final controller = V26Controller.instance..bind(state);
  var status = session.status;
  final note = TextEditingController(text: session.note);
  final previous = session;
  try {
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Revisar presença • ${state.subjectName(session.subjectId)}'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_dateLabel(session.date)} • ${session.start}–${session.end} • ${session.classCount} aula${session.classCount == 1 ? '' : 's'}'),
                const SizedBox(height: 14),
                SegmentedButton<AttendanceStatus>(
                  segments: const [
                    ButtonSegment(value: AttendanceStatus.pending, icon: Icon(Icons.schedule_rounded), label: Text('Pendente')),
                    ButtonSegment(value: AttendanceStatus.present, icon: Icon(Icons.check_circle_outline_rounded), label: Text('Presente')),
                    ButtonSegment(value: AttendanceStatus.absent, icon: Icon(Icons.cancel_outlined), label: Text('Faltei')),
                    ButtonSegment(value: AttendanceStatus.cancelled, icon: Icon(Icons.event_busy_outlined), label: Text('Cancelada')),
                  ],
                  selected: {status},
                  onSelectionChanged: (value) => setLocal(() => status = value.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: note,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: status == AttendanceStatus.absent ? 'Motivo / observação da falta' : 'Observação',
                    hintText: status == AttendanceStatus.absent ? 'Opcional: saúde, compromisso, transporte...' : 'Opcional',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () async {
                try {
                  await controller.changeAttendance(session, status, note: note.text);
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (error) {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('$error')));
                  }
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (changed == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Registro de presença atualizado.'),
          action: SnackBarAction(
            label: 'DESFAZER',
            onPressed: () => controller.undoAttendance(previous),
          ),
        ),
      );
    }
  } finally {
    note.dispose();
  }
}

DateTime _defaultStudyTime(DateTime value) {
  final base = DateTime(value.year, value.month, value.day, value.hour, value.minute);
  if (base.isAfter(DateTime.now().add(const Duration(minutes: 15)))) return base;
  final now = DateTime.now();
  final roundedMinutes = ((now.minute ~/ 15) + 1) * 15;
  return DateTime(now.year, now.month, now.day, now.hour, 0).add(Duration(minutes: roundedMinutes));
}

String _dateLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
String _timeLabel(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
