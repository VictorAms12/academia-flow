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
    final sessionTarget = AttachmentTarget(type: AttachmentTargetType.classSession, id: sessionId, subjectId: session.subjectId);
    final attachmentTitle = '${subject?.name ?? 'Aula'} • ${formatRoutineDate(session.date)}';

    return Scaffold(
      appBar: AppBar(title: Text(subject?.name ?? 'Aula')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SoftCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    GoldBadge(session.kind == ClassSessionKind.regular ? 'AULA' : session.kind == ClassSessionKind.makeup ? 'REPOSIÇÃO' : 'EXTRA'),
                    const Spacer(),
                    _StatusBadge(session.status),
                  ]),
                  const SizedBox(height: 14),
                  Text('${formatRoutineDate(session.date)} • ${session.start}–${session.end}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text('${session.classCount} aula${session.classCount == 1 ? '' : 's'}${session.room.isEmpty ? '' : ' • ${session.room}'}', style: Theme.of(context).textTheme.bodyMedium),
                  if (session.note.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(session.note, style: Theme.of(context).textTheme.bodySmall),
                  ],
                  if (!started && session.status == AttendanceStatus.pending) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(Icons.schedule_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 7),
                      Expanded(child: Text('A presença fica disponível quando a aula começar.', style: Theme.of(context).textTheme.bodySmall)),
                    ]),
                  ],
                  const SizedBox(height: 18),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    FilledButton.icon(
                      onPressed: !started || session.status == AttendanceStatus.present ? null : () => markAttendanceWithFeedback(context, state, session, AttendanceStatus.present),
                      icon: Icon(session.status == AttendanceStatus.present ? Icons.verified_rounded : Icons.check_rounded),
                      label: Text(session.status == AttendanceStatus.present ? 'Presença registrada' : 'Presente'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: !started || session.status == AttendanceStatus.absent ? null : () => markAttendanceWithFeedback(context, state, session, AttendanceStatus.absent),
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
              SectionTitle(
                'Conteúdo da aula',
                trailing: PopupMenuButton<String>(
                  tooltip: 'Adicionar conteúdo',
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  onSelected: (value) {
                    if (value == 'note') showSessionNoteEditor(context, state, session);
                    if (value == 'material') showSessionMaterialEditor(context, state, session);
                    if (value == 'task') showSessionTaskEditor(context, state, session);
                    if (value == 'attachment') showAttachmentManager(context, target: sessionTarget, title: attachmentTitle);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'note', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.note_add_outlined), title: Text('Anotação'))),
                    PopupMenuItem(value: 'material', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.menu_book_outlined), title: Text('Material'))),
                    PopupMenuItem(value: 'task', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.add_task_rounded), title: Text('Atividade'))),
                    PopupMenuItem(value: 'attachment', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.attach_file_rounded), title: Text('Foto ou arquivo'))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (notes.isEmpty && materials.isEmpty && tasks.isEmpty)
                EmptyState(
                  icon: Icons.auto_stories_outlined,
                  title: ended ? 'Feche o ciclo desta aula' : 'Prepare esta aula',
                  message: ended ? 'Adicione uma anotação, material, anexo ou nova atividade antes de seguir.' : 'Você pode vincular materiais, fotos e anotações a esta aula desde já.',
                  actionLabel: 'Adicionar anotação',
                  onAction: () => showSessionNoteEditor(context, state, session),
                )
              else ...[
                if (notes.isNotEmpty)
                  _Group(
                    title: 'Anotações',
                    icon: Icons.notes_rounded,
                    children: [for (final item in notes) _NoteTile(state: state, session: session, note: item)],
                  ),
                if (materials.isNotEmpty)
                  _Group(
                    title: 'Materiais',
                    icon: Icons.menu_book_outlined,
                    children: [for (final item in materials) _MaterialTile(state: state, item: item)],
                  ),
                if (tasks.isNotEmpty)
                  _Group(
                    title: 'Atividades',
                    icon: Icons.task_alt_rounded,
                    children: [for (final item in tasks) _TaskTile(state: state, item: item)],
                  ),
              ],
              const SizedBox(height: 4),
              AttachmentSummaryCard(target: sessionTarget, title: attachmentTitle),
              if (session.status == AttendanceStatus.cancelled && session.kind == ClassSessionKind.regular) ...[
                const SizedBox(height: 16),
                SoftCard(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final text = const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Precisa repor esta aula?', style: TextStyle(fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('Crie uma reposição vinculada a este encontro.'),
                      ]);
                      final action = FilledButton.tonalIcon(
                        onPressed: () => showExtraClassEditor(context, state, kind: ClassSessionKind.makeup, makeupFor: session),
                        icon: const Icon(Icons.replay_rounded),
                        label: const Text('Reposição'),
                      );
                      if (constraints.maxWidth < 480) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [text, const SizedBox(height: 12), action]);
                      return Row(children: [const Expanded(child: SizedBox()), Expanded(flex: 4, child: text), const SizedBox(width: 12), action]);
                    },
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.state, required this.session, required this.note});
  final AppState state;
  final ClassSession session;
  final AcademicNote note;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () => showSessionNoteEditor(context, state, session, note: note),
        leading: note.pinned ? const Icon(Icons.push_pin_rounded, size: 18, color: AppColors.gold) : const Icon(Icons.notes_rounded, size: 18),
        title: Text(note.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: note.content.isEmpty ? const Text('Sem conteúdo') : Text(note.content, maxLines: 3, overflow: TextOverflow.ellipsis),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') await showSessionNoteEditor(context, state, session, note: note);
            if (value == 'attachments' && note.id != null) {
              await showAttachmentManager(context, target: AttachmentTarget(type: AttachmentTargetType.note, id: note.id!, subjectId: note.subjectId), title: note.title);
            }
            if (value == 'delete' && await _confirmDelete(context, note.title)) {
              await state.deleteNote(note);
              if (context.mounted) _feedback(context, 'Anotação excluída.');
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            if (note.id != null) const PopupMenuItem(value: 'attachments', child: Text('Anexos')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
      );
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.state, required this.item});
  final AppState state;
  final MaterialResource item;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.menu_book_outlined, size: 18),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(item.url.isEmpty ? (item.description.isEmpty ? 'Sem descrição' : item.description) : item.url, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'attachments' && item.id != null) {
              await showAttachmentManager(context, target: AttachmentTarget(type: AttachmentTargetType.material, id: item.id!, subjectId: item.subjectId), title: item.title);
            }
            if (value == 'delete' && await _confirmDelete(context, item.title)) {
              await state.deleteMaterial(item);
              if (context.mounted) _feedback(context, 'Material excluído.');
            }
          },
          itemBuilder: (_) => [
            if (item.id != null) const PopupMenuItem(value: 'attachments', child: Text('Anexos')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
      );
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.state, required this.item});
  final AppState state;
  final AcademicTask item;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(item.status == TaskStatus.done ? Icons.task_alt_rounded : Icons.pending_actions_outlined, size: 18),
        title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text('Prazo ${formatRoutineDate(item.dueDate)} • ${item.status == TaskStatus.done ? 'Concluída' : item.status == TaskStatus.doing ? 'Em andamento' : 'Pendente'}'),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'attachments' && item.id != null) {
              await showAttachmentManager(context, target: AttachmentTarget(type: AttachmentTargetType.task, id: item.id!, subjectId: item.subjectId), title: item.title);
            }
            if (value == 'toggle') await state.moveTask(item, item.status == TaskStatus.done ? TaskStatus.todo : TaskStatus.done);
            if (value == 'delete' && await _confirmDelete(context, item.title)) {
              await state.deleteTask(item);
              if (context.mounted) _feedback(context, 'Atividade excluída.');
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'toggle', child: Text(item.status == TaskStatus.done ? 'Reabrir' : 'Marcar como concluída')),
            if (item.id != null) const PopupMenuItem(value: 'attachments', child: Text('Anexos')),
            const PopupMenuDivider(),
            const PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
      );
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, size: 18), const SizedBox(width: 7), Text(title, style: const TextStyle(fontWeight: FontWeight.w900))]),
            const SizedBox(height: 6),
            ...children,
          ]),
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
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900)),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, String title) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir?'),
        content: Text('“$title” será removido. Anexos vinculados também serão apagados do índice e limpos do armazenamento interno.'),
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

void _feedback(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
