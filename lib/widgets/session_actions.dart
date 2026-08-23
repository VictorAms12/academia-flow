import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import 'routine_dialogs.dart';

Future<void> showExtraClassEditor(BuildContext context, AppState state, {ClassSessionKind kind = ClassSessionKind.extra, ClassSession? makeupFor}) async {
  if (state.subjects.isEmpty) return;
  int subjectId = makeupFor?.subjectId ?? state.subjects.first.id!;
  DateTime date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay start = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay end = const TimeOfDay(hour: 20, minute: 40);
  int classCount = makeupFor?.classCount ?? 2;
  final room = TextEditingController(text: makeupFor?.room ?? '');

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(kind == ClassSessionKind.makeup ? 'Reposição de aula' : 'Aula extraordinária'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<int>(initialValue: subjectId, decoration: const InputDecoration(labelText: 'Matéria'), items: state.subjects.map((s) => DropdownMenuItem(value: s.id!, child: Text(s.name))).toList(), onChanged: (v) => setLocal(() => subjectId = v ?? subjectId)),
                const SizedBox(height: 12),
                ListTile(contentPadding: EdgeInsets.zero, title: const Text('Data'), subtitle: Text(formatRoutineDate(date)), trailing: const Icon(Icons.calendar_month_rounded), onTap: () async {
                  final selected = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now().subtract(const Duration(days: 30)), lastDate: DateTime(2100));
                  if (selected != null) setLocal(() => date = selected);
                }),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _TimeBox(label: 'Início', time: start, onTap: () async { final v = await showTimePicker(context: context, initialTime: start); if (v != null) setLocal(() => start = v); })),
                  const SizedBox(width: 10),
                  Expanded(child: _TimeBox(label: 'Fim', time: end, onTap: () async { final v = await showTimePicker(context: context, initialTime: end); if (v != null) setLocal(() => end = v); })),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(initialValue: classCount, decoration: const InputDecoration(labelText: 'Quantidade de aulas'), items: [for (var i = 1; i <= 6; i++) DropdownMenuItem(value: i, child: Text('$i'))], onChanged: (v) => setLocal(() => classCount = v ?? classCount)),
                const SizedBox(height: 12),
                TextFormField(controller: room, decoration: const InputDecoration(labelText: 'Sala / local')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(onPressed: () async {
              if (_minutes(end) <= _minutes(start)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('O horário final deve ser posterior ao horário inicial.')));
                return;
              }
              try {
                await state.saveClassSession(ClassSession(subjectId: subjectId, date: date, start: _time(start), end: _time(end), room: room.text.trim(), classCount: classCount, kind: kind, makeupForSessionId: makeupFor?.id, createdAt: DateTime.now()));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (error) {
                if (dialogContext.mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Não foi possível adicionar a aula: $error')));
              }
            }, child: const Text('Adicionar')),
          ],
        ),
      ),
    );
  } finally {
    room.dispose();
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

class _TimeBox extends StatelessWidget {
  const _TimeBox({required this.label, required this.time, required this.onTap});
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: InputDecorator(decoration: InputDecoration(labelText: label), child: Text(_time(time))));
}
