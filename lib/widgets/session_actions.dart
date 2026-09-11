import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'routine_dialogs.dart';

Future<ClassSession?> showExtraClassEditor(
  BuildContext context,
  AppState state, {
  ClassSessionKind kind = ClassSessionKind.extra,
  ClassSession? makeupFor,
  ClassSession? existing,
}) async {
  if (state.subjects.isEmpty) return null;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final resolvedKind = existing?.kind ?? kind;
  final linkedOriginal = makeupFor ?? state.sessionById(existing?.makeupForSessionId);

  int subjectId = existing?.subjectId ?? linkedOriginal?.subjectId ?? state.subjects.first.id!;
  final linkedDate = linkedOriginal?.date;
  DateTime date = existing?.date ??
      (linkedDate != null && !DateTime(linkedDate.year, linkedDate.month, linkedDate.day).isBefore(today)
          ? linkedDate
          : today);
  TimeOfDay start = _parseTime(existing?.start ?? linkedOriginal?.start, const TimeOfDay(hour: 19, minute: 0));
  TimeOfDay end = _parseTime(existing?.end ?? linkedOriginal?.end, const TimeOfDay(hour: 20, minute: 40));
  int classCount = existing?.classCount ?? linkedOriginal?.classCount ?? 2;
  final room = TextEditingController(text: existing?.room ?? linkedOriginal?.room ?? '');
  final note = TextEditingController(text: existing?.note ?? '');
  var saving = false;
  String? saveError;

  try {
    final saved = await showDialog<ClassSession>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(
              existing != null
                  ? (resolvedKind == ClassSessionKind.makeup ? 'Editar reposição' : 'Editar aula extra')
                  : (resolvedKind == ClassSessionKind.makeup ? 'Reposição de aula' : 'Aula extra'),
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (linkedOriginal != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.replay_rounded, size: 20),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Reposição vinculada à aula de ${formatRoutineDate(linkedOriginal.date)} • ${linkedOriginal.start}–${linkedOriginal.end}. Você pode alterar a nova data e horário abaixo.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 13),
                    ],
                    DropdownButtonFormField<int>(
                      initialValue: subjectId,
                      decoration: const InputDecoration(labelText: 'Matéria'),
                      items: state.subjects
                          .where((subject) => subject.id != null)
                          .map((subject) => DropdownMenuItem(value: subject.id!, child: Text(subject.name)))
                          .toList(),
                      onChanged: saving ? null : (value) => setLocal(() => subjectId = value ?? subjectId),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      enabled: !saving,
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      title: const Text('Data'),
                      subtitle: Text(formatRoutineDate(date)),
                      trailing: const Icon(Icons.calendar_month_rounded),
                      onTap: saving
                          ? null
                          : () async {
                              final selected = await showDatePicker(
                                context: context,
                                initialDate: date,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (selected != null) setLocal(() => date = selected);
                            },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeBox(
                            label: 'Início',
                            time: start,
                            enabled: !saving,
                            onTap: () async {
                              final value = await showTimePicker(context: context, initialTime: start);
                              if (value != null) setLocal(() => start = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TimeBox(
                            label: 'Fim',
                            time: end,
                            enabled: !saving,
                            onTap: () async {
                              final value = await showTimePicker(context: context, initialTime: end);
                              if (value != null) setLocal(() => end = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: classCount,
                      decoration: const InputDecoration(labelText: 'Quantidade de aulas'),
                      items: [for (var i = 1; i <= 8; i++) DropdownMenuItem(value: i, child: Text('$i'))],
                      onChanged: saving ? null : (value) => setLocal(() => classCount = value ?? classCount),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      enabled: !saving,
                      controller: room,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Sala / local'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      enabled: !saving,
                      controller: note,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Observação',
                        hintText: 'Ex.: aula colocada no lugar da aula cancelada',
                      ),
                    ),
                    if (saveError != null) ...[
                      const SizedBox(height: 11),
                      Text(saveError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    if (saving) ...[
                      const SizedBox(height: 13),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Text(
                        existing == null ? 'Salvando aula e atualizando a rotina…' : 'Atualizando aula e rotina…',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        if (_minutes(end) <= _minutes(start)) {
                          setLocal(() => saveError = 'O horário final deve ser posterior ao horário inicial.');
                          return;
                        }
                        setLocal(() {
                          saving = true;
                          saveError = null;
                        });
                        try {
                          final draft = existing == null
                              ? ClassSession(
                                  subjectId: subjectId,
                                  date: date,
                                  start: _time(start),
                                  end: _time(end),
                                  room: room.text.trim(),
                                  classCount: classCount,
                                  kind: resolvedKind,
                                  note: note.text.trim(),
                                  makeupForSessionId: linkedOriginal?.id,
                                  createdAt: DateTime.now(),
                                )
                              : existing.copyWith(
                                  subjectId: subjectId,
                                  date: date,
                                  start: _time(start),
                                  end: _time(end),
                                  room: room.text.trim(),
                                  classCount: classCount,
                                  kind: resolvedKind,
                                  note: note.text.trim(),
                                  makeupForSessionId: linkedOriginal?.id,
                                );
                          final result = await state.saveClassSession(draft);
                          if (dialogContext.mounted) Navigator.pop(dialogContext, result);
                        } catch (error) {
                          if (!dialogContext.mounted) return;
                          setLocal(() {
                            saving = false;
                            saveError = 'Não foi possível salvar a aula: $error';
                          });
                        }
                      },
                icon: saving
                    ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(existing == null ? Icons.add_rounded : Icons.save_outlined),
                label: Text(saving ? 'Salvando…' : existing == null ? 'Adicionar' : 'Salvar alterações'),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != null && context.mounted) {
      final label = resolvedKind == ClassSessionKind.makeup ? 'Reposição' : 'Aula extra';
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('$label ${existing == null ? 'adicionada' : 'atualizada'} • ${formatRoutineDate(saved.date)} às ${saved.start}.'),
        ),
      );
    }
    return saved;
  } finally {
    room.dispose();
    note.dispose();
  }
}

Future<void> showSessionNoteEditor(BuildContext context, AppState state, ClassSession session, {AcademicNote? note}) async {
  final editing = note != null;
  final title = TextEditingController(text: note?.title ?? 'Aula ${formatRoutineDate(session.date)}');
  final content = TextEditingController(text: note?.content ?? '');
  final tags = TextEditingController(text: note?.tags ?? '');
  var saving = false;
  String? error;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text(editing ? 'Editar anotação da aula' : 'Anotação da aula'),
            content: SizedBox(
              width: 540,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(enabled: !saving, controller: title, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Título')),
                  const SizedBox(height: 12),
                  TextField(enabled: !saving, controller: content, minLines: 5, maxLines: 10, decoration: const InputDecoration(labelText: 'Anotação')),
                  const SizedBox(height: 12),
                  TextField(enabled: !saving, controller: tags, decoration: const InputDecoration(labelText: 'Tags', hintText: 'ex.: revisão, prova')),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerLeft, child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                  ],
                  if (saving) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                  ],
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              FilledButton.icon(
                onPressed: saving ? null : () async {
                  if (title.text.trim().isEmpty) {
                    setLocal(() => error = 'Informe um título.');
                    return;
                  }
                  setLocal(() { saving = true; error = null; });
                  try {
                    await state.saveNote(AcademicNote(
                      id: note?.id,
                      subjectId: session.subjectId,
                      sessionId: session.id,
                      title: title.text.trim(),
                      content: content.text.trim(),
                      link: note?.link ?? '',
                      tags: tags.text.trim(),
                      pinned: note?.pinned ?? false,
                      createdAt: note?.createdAt ?? DateTime.now(),
                    ));
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                  } catch (e) {
                    if (dialogContext.mounted) setLocal(() { saving = false; error = 'Não foi possível salvar: $e'; });
                  }
                },
                icon: saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Salvando…' : 'Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  } finally {
    title.dispose();
    content.dispose();
    tags.dispose();
  }
}

Future<void> showSessionMaterialEditor(BuildContext context, AppState state, ClassSession session) async {
  final title = TextEditingController();
  final url = TextEditingController();
  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Material da aula'),
        content: SizedBox(width: 520, child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: title, decoration: const InputDecoration(labelText: 'Título')), const SizedBox(height: 12), TextField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Link / referência'))])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            if (title.text.trim().isEmpty) return;
            await state.saveMaterial(MaterialResource(subjectId: session.subjectId, sessionId: session.id, title: title.text.trim(), url: url.text.trim(), createdAt: DateTime.now()));
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          }, child: const Text('Salvar')),
        ],
      ),
    );
  } finally {
    title.dispose();
    url.dispose();
  }
}

Future<void> showSessionTaskEditor(BuildContext context, AppState state, ClassSession session) async {
  final title = TextEditingController();
  DateTime due = DateTime.now().add(const Duration(days: 7));
  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Atividade a partir da aula'),
          content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, autofocus: true, decoration: const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 12),
            ListTile(contentPadding: EdgeInsets.zero, title: const Text('Prazo'), subtitle: Text(formatRoutineDate(due)), trailing: const Icon(Icons.calendar_month_rounded), onTap: () async { final v = await showDatePicker(context: context, initialDate: due, firstDate: DateTime.now(), lastDate: DateTime(2100)); if (v != null) setLocal(() => due = v); }),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(onPressed: () async {
              if (title.text.trim().isEmpty) return;
              await state.saveTask(AcademicTask(title: title.text.trim(), subjectId: session.subjectId, sessionId: session.id, dueDate: due, description: 'Criada a partir da aula de ${formatRoutineDate(session.date)}.'));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }, child: const Text('Criar')),
          ],
        ),
      ),
    );
  } finally {
    title.dispose();
  }
}

Future<void> showRoutineSettings(BuildContext context, AppState state) async {
  bool before = state.classRemindersEnabled;
  bool checkin = state.attendanceCheckInEnabled;
  bool pending = state.endPendingReminderEnabled;
  bool endActions = state.endClassActionsEnabled;
  bool streak = state.streakEnabled;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: const Text('Automação da rotina'),
        content: SizedBox(width: 500, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          SwitchListTile(value: before, title: const Text('Lembrar antes da aula'), subtitle: const Text('Usa o tempo configurado em cada bloco.'), onChanged: (v) => setLocal(() => before = v)),
          SwitchListTile(value: checkin, title: const Text('Perguntar presença no início'), onChanged: (v) => setLocal(() => checkin = v)),
          SwitchListTile(value: pending, title: const Text('Lembrar presença pendente no fim'), onChanged: (v) => setLocal(() => pending = v)),
          SwitchListTile(value: endActions, title: const Text('Aviso de ações ao fim da aula'), subtitle: const Text('Anotação, material ou nova atividade.'), onChanged: (v) => setLocal(() => endActions = v)),
          SwitchListTile(value: streak, title: const Text('Mostrar sequência de presenças'), onChanged: (v) => setLocal(() => streak = v)),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(onPressed: () async {
            await state.updateRoutineSettings(classReminders: before, attendanceCheckIn: checkin, endPendingReminder: pending, endClassActions: endActions, streak: streak);
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          }, child: const Text('Salvar')),
        ],
      ),
    ),
  );
}

int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;
String _time(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay _parseTime(String? value, TimeOfDay fallback) {
  if (value == null) return fallback;
  final parts = value.split(':');
  if (parts.length != 2) return fallback;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
  return TimeOfDay(hour: hour, minute: minute);
}

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.time, required this.onTap, this.enabled = true});
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          isEmpty: false,
          decoration: InputDecoration(labelText: label, enabled: enabled),
          child: Text(_time(time)),
        ),
      );
}
