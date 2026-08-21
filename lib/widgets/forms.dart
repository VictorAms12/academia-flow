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

  try {
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
                          validator: _nonNegativeIntegerValidator,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: absences,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Faltas'),
                          validator: _nonNegativeIntegerValidator,
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
              final total = int.parse(totalClasses.text.trim());
              final misses = int.parse(absences.text.trim());
              if (misses > total) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
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
                  totalClasses: total,
                  absences: misses,
                ),
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  } finally {
    name.dispose();
    professor.dispose();
    room.dispose();
    totalClasses.dispose();
    absences.dispose();
  }
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

  try {
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
                      borderRadius: BorderRadius.circular(14),
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
                        child: Text(_formatDate(date)),
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
  } finally {
    title.dispose();
    value.dispose();
    weight.dispose();
  }
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
  var saving = false;
  String? saveError;

  try {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => PopScope(
          canPop: !saving,
          child: AlertDialog(
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
                      onChanged: saving
                          ? null
                          : (v) => setLocal(() {
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
                      onChanged: saving ? null : (v) => setLocal(() => day = v ?? day),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeField(
                            label: 'Início',
                            time: start,
                            enabled: !saving,
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
                            enabled: !saving,
                            onTap: () async {
                              final selected = await showTimePicker(context: context, initialTime: end);
                              if (selected != null) setLocal(() => end = selected);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(controller: room, enabled: !saving, decoration: const InputDecoration(labelText: 'Sala / local')),
                    if (saving) ...[
                      const SizedBox(height: 18),
                      const LinearProgressIndicator(minHeight: 4),
                      const SizedBox(height: 9),
                      Text(
                        entry == null
                            ? 'Salvando horário e preparando as próximas aulas…'
                            : 'Salvando alteração e atualizando as próximas aulas…',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (saveError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: .55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          saveError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer, fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
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
                          if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                        } catch (error) {
                          if (!dialogContext.mounted) return;
                          setLocal(() {
                            saving = false;
                            saveError = 'Não foi possível salvar o horário. ${_friendlyError(error)}';
                          });
                        }
                      },
                icon: saving
                    ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Salvando…' : 'Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            entry == null
                ? 'Horário salvo. As próximas aulas foram preparadas.'
                : 'Horário atualizado. As próximas aulas foram recalculadas.',
          ),
        ),
      );
    }
  } finally {
    room.dispose();
  }
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

String? _nonNegativeIntegerValidator(String? value) {
  final n = int.tryParse((value ?? '').trim());
  if (n == null) return 'Informe um número inteiro';
  if (n < 0) return 'Não pode ser negativo';
  if (n > 9999) return 'Valor muito alto';
  return null;
}

TimeOfDay _parseTime(String value) {
  final parts = value.split(':');
  final hour = int.tryParse(parts.first) ?? 19;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
}

int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;
String _formatTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _friendlyError(Object error) {
  final text = '$error'.replaceFirst('ArgumentError: ', '').replaceFirst('StateError: ', '').trim();
  return text.isEmpty ? 'Tente novamente.' : text;
}

class _TimeField extends StatelessWidget {
  const _TimeField({required this.label, required this.time, required this.onTap, this.enabled = true});
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, enabled: enabled),
        child: Text(_formatTime(time)),
      ),
    );
  }
}
