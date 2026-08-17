import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/attendance_feedback.dart';
import '../widgets/common.dart';
import '../widgets/routine_dialogs.dart';
import '../widgets/session_actions.dart';

class ClassDetailScreen extends StatelessWidget {
  const ClassDetailScreen({super.key, required this.sessionId});
  final int sessionId;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final session = state.sessionById(sessionId);
    if (session == null) {
      return Scaffold(appBar: AppBar(title: const Text('Aula')), body: const Center(child: Text('Aula não encontrada.')));
    }
    final notes = state.notesForSession(sessionId);
    final materials = state.materialsForSession(sessionId);
    final tasks = state.tasksForSession(sessionId);
    final subject = state.subjectById(session.subjectId);
    final now = DateTime.now();
    final ended = now.isAfter(session.endsAt);

    return Scaffold(
      appBar: AppBar(title: Text(state.subjectName(session.subjectId))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoftCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      _StatusBadge(session.status),
                      _KindBadge(session.kind),
                      GoldBadge('${session.classCount} aula${session.classCount == 1 ? '' : 's'}'),
                    ]),
                    const SizedBox(height: 15),
                    Text(formatRoutineDate(session.date), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('${session.start}–${session.end}${session.room.isEmpty ? '' : ' • ${session.room}'}', style: Theme.of(context).textTheme.titleMedium),
                    if (subject?.professor.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(subject!.professor, style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const SizedBox(height: 18),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      FilledButton.icon(
                        onPressed: session.status == AttendanceStatus.present ? null : () => markAttendanceWithFeedback(context, state, session, AttendanceStatus.present),
                        icon: Icon(session.status == AttendanceStatus.present ? Icons.verified_rounded : Icons.check_rounded),
                        label: Text(session.status == AttendanceStatus.present ? 'Presença registrada' : 'Presente'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: session.status == AttendanceStatus.absent ? null : () => markAttendanceWithFeedback(context, state, session, AttendanceStatus.absent),
                        icon: const Icon(Icons.close_rounded),
                        label: Text(session.status == AttendanceStatus.absent ? 'Falta registrada' : 'Faltei'),
                      ),
                      OutlinedButton.icon(
                        onPressed: session.status == AttendanceStatus.cancelled ? null : () => markAttendanceWithFeedback(context, state, session, AttendanceStatus.cancelled),
                        icon: const Icon(Icons.event_busy_rounded),
                        label: Text(session.status == AttendanceStatus.cancelled ? 'Aula cancelada' : 'Cancelada'),
                      ),
                    ]),
                  ]),
                ),
                const SizedBox(height: 16),
                if (ended)
                  SoftCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SectionTitle('Aula encerrada'),
                      const SizedBox(height: 8),
                      const Text('Registre o que surgiu desta aula sem precisar procurar outra tela.'),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        FilledButton.tonalIcon(onPressed: () => showSessionNoteEditor(context, state, session), icon: const Icon(Icons.note_add_outlined), label: const Text('Anotação')),
                        FilledButton.tonalIcon(onPressed: () => showSessionMaterialEditor(context, state, session), icon: const Icon(Icons.link_rounded), label: const Text('Material')),
                        FilledButton.tonalIcon(onPressed: () => showSessionTaskEditor(context, state, session), icon: const Icon(Icons.add_task_rounded), label: const Text('Criar atividade')),
                        if (session.status == AttendanceStatus.cancelled)
                          OutlinedButton.icon(onPressed: () => showExtraClassEditor(context, state, kind: ClassSessionKind.makeup, makeupFor: session), icon: const Icon(Icons.replay_rounded), label: const Text('Criar reposição')),
                      ]),
                    ]),
                  ),
                const SizedBox(height: 16),
                _LinkedSection(
                  title: 'Anotações da aula',
                  empty: 'Nenhuma anotação vinculada.',
                  action: TextButton.icon(onPressed: () => showSessionNoteEditor(context, state, session), icon: const Icon(Icons.add_rounded), label: const Text('Adicionar')),
                  children: [for (final note in notes) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.notes_rounded), title: Text(note.title), subtitle: note.content.isEmpty ? null : Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis))],
                ),
                const SizedBox(height: 16),
                _LinkedSection(
                  title: 'Materiais desta aula',
                  empty: 'Nenhum material vinculado.',
                  action: TextButton.icon(onPressed: () => showSessionMaterialEditor(context, state, session), icon: const Icon(Icons.add_rounded), label: const Text('Adicionar')),
                  children: [for (final item in materials) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.attach_file_rounded), title: Text(item.title), subtitle: item.url.isEmpty ? null : Text(item.url, maxLines: 1, overflow: TextOverflow.ellipsis))],
                ),
                const SizedBox(height: 16),
                _LinkedSection(
                  title: 'Atividades originadas aqui',
                  empty: 'Nenhuma atividade criada a partir desta aula.',
                  action: TextButton.icon(onPressed: () => showSessionTaskEditor(context, state, session), icon: const Icon(Icons.add_rounded), label: const Text('Criar')),
                  children: [for (final task in tasks) ListTile(contentPadding: EdgeInsets.zero, leading: Icon(task.status == TaskStatus.done ? Icons.task_alt_rounded : Icons.task_outlined), title: Text(task.title), subtitle: Text('Prazo ${formatRoutineDate(task.dueDate)}'))],
                ),
                if (session.note.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SectionTitle('Observação'), const SizedBox(height: 8), Text(session.note)])),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkedSection extends StatelessWidget {
  const _LinkedSection({required this.title, required this.empty, required this.action, required this.children});
  final String title;
  final String empty;
  final Widget action;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionTitle(title, trailing: action),
          const SizedBox(height: 8),
          if (children.isEmpty) Text(empty, style: Theme.of(context).textTheme.bodySmall) else ...children,
        ]),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final AttendanceStatus status;
  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      AttendanceStatus.present => 'PRESENTE',
      AttendanceStatus.absent => 'FALTA',
      AttendanceStatus.cancelled => 'CANCELADA',
      AttendanceStatus.pending => 'PENDENTE',
    };
    final color = switch (status) {
      AttendanceStatus.present => AppColors.success,
      AttendanceStatus.absent => AppColors.danger,
      AttendanceStatus.cancelled => Colors.grey,
      AttendanceStatus.pending => AppColors.gold,
    };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)));
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge(this.kind);
  final ClassSessionKind kind;
  @override
  Widget build(BuildContext context) {
    final label = switch (kind) { ClassSessionKind.regular => 'REGULAR', ClassSessionKind.extra => 'EXTRA', ClassSessionKind.makeup => 'REPOSIÇÃO' };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)), child: Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)));
  }
}
