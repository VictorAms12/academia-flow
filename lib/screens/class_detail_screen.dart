import 'package:flutter/material.dart';

import '../models/attachment.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/attachment_summary.dart';
import '../widgets/attendance_feedback.dart';
import '../widgets/common.dart';
import '../widgets/routine_dialogs.dart';
import '../widgets/session_actions.dart';
import 'attachment_manager_screen.dart';

class ClassDetailScreen extends StatelessWidget {
  const ClassDetailScreen({super.key, required this.sessionId});
  final int sessionId;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final session = state.sessionById(sessionId);
    if (session == null) return const Scaffold(body: Center(child: Text('Aula não encontrada.')));
    final subject = state.subjectById(session.subjectId);
    final notes = state.notesForSession(sessionId);
    final materials = state.materialsForSession(sessionId);
    final tasks = state.tasksForSession(sessionId);
    final now = DateTime.now();
    final started = !now.isBefore(session.startsAt);
    final ended = !now.isBefore(session.endsAt);
    final sessionTarget = AttachmentTarget(
      type: AttachmentTargetType.classSession,
      id: sessionId,
      subjectId: session.subjectId,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(subject?.name ?? 'Aula'),
        actions: [
          IconButton(
            tooltip: 'Anexos da aula',
            onPressed: () => showAttachmentManager(
              context,
              target: sessionTarget,
              title: '${subject?.name ?? 'Aula'} • ${formatRoutineDate(session.date)}',
            ),
            icon: const Icon(Icons.attach_file_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          GoldBadge(
                            session.kind == ClassSessionKind.regular
                                ? 'AULA'
                                : session.kind == ClassSessionKind.makeup
                                    ? 'REPOSIÇÃO'
                                    : 'EXTRA',
                          ),
                          const Spacer(),
                          _StatusBadge(session.status),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '${formatRoutineDate(session.date)} • ${session.start}–${session.end}',
                        style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${session.classCount} aula${session.classCount == 1 ? '' : 's'}${session.room.isEmpty ? '' : ' • ${session.room}'}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (session.note.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        Text(session.note, style: Theme.of(context).textTheme.bodySmall),
                      ],
                      if (!started && session.status == AttendanceStatus.pending) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                'A presença fica disponível quando a aula começar.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.icon(
                            onPressed: !started || session.status == AttendanceStatus.present
                                ? null
                                : () => markAttendanceWithFeedback(context, state, session, AttendanceStatus.present),
                            icon: Icon(session.status == AttendanceStatus.present ? Icons.verified_rounded : Icons.check_rounded),
                            label: Text(session.status == AttendanceStatus.present ? 'Presença registrada' : 'Presente'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: !started || session.status == AttendanceStatus.absent
                                ? null
                                : () => markAttendanceWithFeedback(context, state, session, AttendanceStatus.absent),
                            icon: const Icon(Icons.close_rounded),
                            label: Text(session.status == AttendanceStatus.absent ? 'Falta registrada' : 'Faltei'),
                          ),
                          OutlinedButton.icon(
                            onPressed: session.status == AttendanceStatus.cancelled
                                ? null
                                : () => markAttendanceWithFeedback(context, state, session, AttendanceStatus.cancelled),
                            icon: const Icon(Icons.event_busy_rounded),
                            label: Text(session.status == AttendanceStatus.cancelled ? 'Aula cancelada' : 'Cancelada'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SectionTitle(
                  'Conteúdo da aula',
                  trailing: Wrap(
                    spacing: 5,
                    children: [
                      IconButton.filledTonal(
                        tooltip: 'Anotação',
                        onPressed: () => showSessionNoteEditor(context, state, session),
                        icon: const Icon(Icons.note_add_outlined),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Material',
                        onPressed: () => showSessionMaterialEditor(context, state, session),
                        icon: const Icon(Icons.menu_book_outlined),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Atividade',
                        onPressed: () => showSessionTaskEditor(context, state, session),
                        icon: const Icon(Icons.add_task_rounded),
                      ),
                      IconButton.filledTonal(
                        tooltip: 'Anexar foto ou arquivo',
                        onPressed: () => showAttachmentManager(
                          context,
                          target: sessionTarget,
                          title: '${subject?.name ?? 'Aula'} • ${formatRoutineDate(session.date)}',
                        ),
                        icon: const Icon(Icons.attach_file_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (notes.isEmpty && materials.isEmpty && tasks.isEmpty)
                  EmptyState(
                    icon: Icons.auto_stories_outlined,
                    title: ended ? 'Feche o ciclo desta aula' : 'Prepare esta aula',
                    message: ended
                        ? 'Adicione uma anotação, material, anexo ou nova atividade antes de seguir.'
                        : 'Você pode vincular materiais, fotos e anotações a esta aula desde já.',
                  )
                else ...[
                  if (notes.isNotEmpty)
                    _Group(
                      title: 'Anotações',
                      icon: Icons.notes_rounded,
                      children: [
                        for (final item in notes)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: item.content.isEmpty ? null : Text(item.content, maxLines: 3, overflow: TextOverflow.ellipsis),
                            trailing: item.id == null
                                ? null
                                : IconButton(
                                    tooltip: 'Anexos',
                                    onPressed: () => showAttachmentManager(
                                      context,
                                      target: AttachmentTarget(
                                        type: AttachmentTargetType.note,
                                        id: item.id!,
                                        subjectId: item.subjectId,
                                      ),
                                      title: item.title,
                                    ),
                                    icon: const Icon(Icons.attach_file_rounded),
                                  ),
                          ),
                      ],
                    ),
                  if (materials.isNotEmpty)
                    _Group(
                      title: 'Materiais',
                      icon: Icons.menu_book_outlined,
                      children: [
                        for (final item in materials)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text(
                              item.url.isEmpty ? item.description : item.url,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: item.id == null
                                ? null
                                : IconButton(
                                    tooltip: 'Anexos',
                                    onPressed: () => showAttachmentManager(
                                      context,
                                      target: AttachmentTarget(
                                        type: AttachmentTargetType.material,
                                        id: item.id!,
                                        subjectId: item.subjectId,
                                      ),
                                      title: item.title,
                                    ),
                                    icon: const Icon(Icons.attach_file_rounded),
                                  ),
                          ),
                      ],
                    ),
                  if (tasks.isNotEmpty)
                    _Group(
                      title: 'Atividades',
                      icon: Icons.task_alt_rounded,
                      children: [
                        for (final item in tasks)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
                            subtitle: Text(
                              'Prazo ${formatRoutineDate(item.dueDate)} • ${item.status == TaskStatus.done ? 'Concluída' : 'Pendente'}',
                            ),
                            trailing: item.id == null
                                ? null
                                : IconButton(
                                    tooltip: 'Anexos',
                                    onPressed: () => showAttachmentManager(
                                      context,
                                      target: AttachmentTarget(
                                        type: AttachmentTargetType.task,
                                        id: item.id!,
                                        subjectId: item.subjectId,
                                      ),
                                      title: item.title,
                                    ),
                                    icon: const Icon(Icons.attach_file_rounded),
                                  ),
                          ),
                      ],
                    ),
                ],
                const SizedBox(height: 4),
                AttachmentSummaryCard(
                  target: sessionTarget,
                  title: '${subject?.name ?? 'Aula'} • ${formatRoutineDate(session.date)}',
                ),
                if (session.status == AttendanceStatus.cancelled && session.kind == ClassSessionKind.regular) ...[
                  const SizedBox(height: 16),
                  SoftCard(
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Precisa repor esta aula?', style: TextStyle(fontWeight: FontWeight.w900)),
                              SizedBox(height: 4),
                              Text('Crie uma reposição vinculada a este encontro.'),
                            ],
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () => showExtraClassEditor(
                            context,
                            state,
                            kind: ClassSessionKind.makeup,
                            makeupFor: session,
                          ),
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Reposição'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.icon, required this.children});
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 7),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 6),
              ...children,
            ],
          ),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.status);
  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AttendanceStatus.present => ('PRESENTE', AppColors.success),
      AttendanceStatus.absent => ('FALTA', AppColors.danger),
      AttendanceStatus.cancelled => ('CANCELADA', Colors.grey),
      AttendanceStatus.pending => ('PENDENTE', AppColors.gold),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }
}
