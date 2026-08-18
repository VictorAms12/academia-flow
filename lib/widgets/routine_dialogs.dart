import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';

Future<void> showScheduleRoutineConfig(BuildContext context, AppState state, ScheduleEntry entry) async {
  int classCount = entry.classCount;
  int reminder = entry.reminderMinutes;
  bool saving = false;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        title: const Text('Automação do bloco'),
        content: SizedBox(
          width: 430,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              initialValue: classCount,
              decoration: const InputDecoration(labelText: 'Quantidade de aulas no bloco'),
              items: [for (var i = 1; i <= 6; i++) DropdownMenuItem(value: i, child: Text('$i aula${i == 1 ? '' : 's'}'))],
              onChanged: saving ? null : (v) => setLocal(() => classCount = v ?? classCount),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: reminder,
              decoration: const InputDecoration(labelText: 'Lembrar antes da aula'),
              items: const [
                DropdownMenuItem(value: 0, child: Text('No horário')),
                DropdownMenuItem(value: 5, child: Text('5 minutos antes')),
                DropdownMenuItem(value: 10, child: Text('10 minutos antes')),
                DropdownMenuItem(value: 15, child: Text('15 minutos antes')),
                DropdownMenuItem(value: 30, child: Text('30 minutos antes')),
              ],
              onChanged: saving ? null : (v) => setLocal(() => reminder = v ?? reminder),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: saving ? null : () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    setLocal(() => saving = true);
                    try {
                      await state.updateScheduleRoutine(entry, classCount: classCount, reminderMinutes: reminder);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    } catch (_) {
                      if (!dialogContext.mounted) return;
                      setLocal(() => saving = false);
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        const SnackBar(content: Text('Não foi possível salvar a automação deste bloco.')),
                      );
                    }
                  },
            child: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}

Future<void> showAttendanceTargetEditor(BuildContext context, AppState state, Subject subject) async {
  double target = state.attendanceTarget(subject);
  bool useGlobal = subject.minAttendance == null;
  final planned = TextEditingController(text: subject.plannedClasses > 0 ? '${subject.plannedClasses}' : '');
  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text('Planejamento de frequência • ${subject.name}'),
          content: SizedBox(
            width: 450,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: planned,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total de aulas planejadas no semestre',
                    hintText: 'Ex.: 80',
                    helperText: 'Necessário para calcular quantas faltas ainda são permitidas.',
                  ),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: useGlobal,
                  title: Text('Usar regra global (${state.minAttendance.toStringAsFixed(0)}%)'),
                  onChanged: (v) => setLocal(() {
                    useGlobal = v;
                    if (v) target = state.minAttendance;
                  }),
                ),
                if (!useGlobal) ...[
                  Slider(value: target.clamp(50, 100).toDouble(), min: 50, max: 100, divisions: 50, label: '${target.toStringAsFixed(0)}%', onChanged: (v) => setLocal(() => target = v)),
                  Text('${target.toStringAsFixed(0)}% de frequência mínima', style: Theme.of(context).textTheme.titleMedium),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Histórico anterior: ${subject.totalClasses} aulas e ${subject.absences} faltas. A automação soma as novas confirmações a esse histórico.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(onPressed: () async {
              final text = planned.text.trim();
              final plannedClasses = text.isEmpty ? 0 : int.tryParse(text);
              if (plannedClasses == null || plannedClasses < 0) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Informe um total de aulas válido.')),
                );
                return;
              }
              if (plannedClasses > 0 && plannedClasses < subject.totalClasses) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('O total planejado não pode ser menor que as ${subject.totalClasses} aulas já contabilizadas.')),
                );
                return;
              }
              await state.setSubjectAttendancePlan(
                subject,
                plannedClasses: plannedClasses,
                target: useGlobal ? null : target,
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }, child: const Text('Salvar')),
          ],
        ),
      ),
    );
  } finally {
    planned.dispose();
  }
}

Future<void> showAbsenceSimulator(BuildContext context, AppState state, Subject subject) async {
  int misses = 1;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) {
        final projected = state.simulatedAttendance(subject, misses);
        final target = state.attendanceTarget(subject);
        return AlertDialog(
          title: Text('Simular faltas • ${subject.name}'),
          content: SizedBox(
            width: 450,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Se eu faltar às próximas $misses aula${misses == 1 ? '' : 's'}:', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Text('${state.attendanceForSubject(subject).toStringAsFixed(1)}% → ${projected.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(projected >= target ? 'Ainda acima da meta de ${target.toStringAsFixed(0)}%' : 'Abaixo da meta de ${target.toStringAsFixed(0)}%', style: TextStyle(color: projected >= target ? Colors.green : Theme.of(context).colorScheme.error)),
              Slider(value: misses.toDouble(), min: 1, max: 12, divisions: 11, label: '$misses', onChanged: (v) => setLocal(() => misses = v.round())),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Fechar'))],
        );
      },
    ),
  );
}

Future<void> showCalendarEventEditor(BuildContext context, AppState state, {AcademicCalendarEvent? event}) async {
  final title = TextEditingController(text: event?.title ?? '');
  DateTime date = event?.date ?? DateTime.now();
  AcademicEventKind kind = event?.kind ?? AcademicEventKind.academicEvent;
  int? subjectId = event?.subjectId;
  bool blocks = event?.blocksClasses ?? false;
  final formKey = GlobalKey<FormState>();

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(event == null ? 'Evento acadêmico' : 'Editar evento'),
          content: SizedBox(
            width: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(controller: title, decoration: const InputDecoration(labelText: 'Título *'), validator: (v) => v == null || v.trim().isEmpty ? 'Informe o título' : null),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AcademicEventKind>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    items: const [
                      DropdownMenuItem(value: AcademicEventKind.holiday, child: Text('Feriado')),
                      DropdownMenuItem(value: AcademicEventKind.recess, child: Text('Recesso')),
                      DropdownMenuItem(value: AcademicEventKind.cancellation, child: Text('Aula cancelada')),
                      DropdownMenuItem(value: AcademicEventKind.examWeek, child: Text('Semana de avaliações')),
                      DropdownMenuItem(value: AcademicEventKind.academicEvent, child: Text('Evento acadêmico')),
                    ],
                    onChanged: (v) => setLocal(() {
                      kind = v ?? kind;
                      if (kind == AcademicEventKind.holiday || kind == AcademicEventKind.recess || kind == AcademicEventKind.cancellation) blocks = true;
                    }),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: subjectId,
                    decoration: const InputDecoration(labelText: 'Matéria afetada'),
                    items: [const DropdownMenuItem<int?>(value: null, child: Text('Todas / evento geral')), ...state.subjects.map((s) => DropdownMenuItem<int?>(value: s.id, child: Text(s.name)))],
                    onChanged: (v) => setLocal(() => subjectId = v),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Data'),
                    subtitle: Text(formatRoutineDate(date)),
                    trailing: const Icon(Icons.calendar_month_rounded),
                    onTap: () async {
                      final selected = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2024), lastDate: DateTime(2100));
                      if (selected != null) setLocal(() => date = selected);
                    },
                  ),
                  SwitchListTile(contentPadding: EdgeInsets.zero, value: blocks, title: const Text('Não gerar aula nesta data'), onChanged: (v) => setLocal(() => blocks = v)),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              await state.saveCalendarEvent(AcademicCalendarEvent(id: event?.id, date: date, title: title.text.trim(), kind: kind, subjectId: subjectId, blocksClasses: blocks));
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            }, child: const Text('Salvar')),
          ],
        ),
      ),
    );
  } finally {
    title.dispose();
  }
}

String formatRoutineDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
