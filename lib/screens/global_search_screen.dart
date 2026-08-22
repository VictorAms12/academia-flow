import 'package:flutter/material.dart';

import '../models/attachment.dart';
import '../models/models.dart';
import '../services/attachment_repository.dart';
import '../state/app_state.dart';
import '../utils/search_engine.dart';
import '../widgets/v22_actions.dart';
import 'attachment_manager_screen.dart';
import 'class_detail_screen.dart';
import 'subject_detail_screen.dart';

enum _SearchType { all, subjects, tasks, notes, materials, classes, attachments }

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final controller = TextEditingController();
  final repository = AttachmentRepository.instance;
  late Future<List<AcademicAttachment>> attachmentFuture;
  String query = '';
  _SearchType type = _SearchType.all;
  int? subjectFilter;

  @override
  void initState() {
    super.initState();
    attachmentFuture = repository.allAttachments();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return FutureBuilder<List<AcademicAttachment>>(
      future: attachmentFuture,
      builder: (context, snapshot) {
        final attachments = snapshot.data ?? const <AcademicAttachment>[];
        final hits = _results(state, attachments);
        final searching = query.trim().isNotEmpty;
        return Scaffold(
          appBar: AppBar(title: const Text('Busca avançada')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (value) => setState(() => query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: 'Matéria, atividade, tag, aula, foto ou arquivo...',
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Limpar',
                            onPressed: () {
                              controller.clear();
                              setState(() => query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _Filters(
                state: state,
                type: type,
                subjectFilter: subjectFilter,
                onTypeChanged: (value) => setState(() => type = value),
                onSubjectChanged: (value) => setState(() => subjectFilter = value),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        searching ? '${hits.length} resultado${hits.length == 1 ? '' : 's'} por relevância' : 'Itens recentes e úteis',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    if (subjectFilter != null || type != _SearchType.all)
                      TextButton(
                        onPressed: () => setState(() {
                          subjectFilter = null;
                          type = _SearchType.all;
                        }),
                        child: const Text('Limpar filtros'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: hits.isEmpty
                    ? _EmptySearch(searching: searching)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 28),
                        itemCount: hits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 3),
                        itemBuilder: (_, index) => _SearchResultTile(hit: hits[index]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_SearchHit> _results(AppState state, List<AcademicAttachment> attachments) {
    final q = query.trim();
    final hits = <_SearchHit>[];
    bool enabled(_SearchType candidate) => type == _SearchType.all || type == candidate;
    bool subjectEnabled(int? subjectId) => subjectFilter == null || subjectId == subjectFilter;
    int score(List<String> fields) => q.isEmpty ? 0 : searchScore(q, fields);

    if (enabled(_SearchType.subjects)) {
      for (final subject in state.subjects) {
        if (subject.id == null || !subjectEnabled(subject.id)) continue;
        final relevance = score([subject.name, subject.professor, subject.room]);
        if (q.isNotEmpty && relevance < 0) continue;
        hits.add(_SearchHit(
          type: _SearchType.subjects,
          title: subject.name,
          subtitle: [if (subject.professor.isNotEmpty) subject.professor, if (subject.room.isNotEmpty) subject.room].join(' • '),
          icon: Icons.auto_stories_outlined,
          score: relevance + 8,
          timestamp: null,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectDetailScreen(subjectId: subject.id!))),
        ));
      }
    }

    if (enabled(_SearchType.tasks)) {
      for (final task in state.tasks) {
        if (!subjectEnabled(task.subjectId)) continue;
        final relevance = score([task.title, task.description, task.checklist.join(' '), state.subjectName(task.subjectId), taskKindLabel(task.kind)]);
        if (q.isNotEmpty && relevance < 0) continue;
        hits.add(_SearchHit(
          type: _SearchType.tasks,
          title: task.title,
          subtitle: '${state.subjectName(task.subjectId)} • ${taskKindLabel(task.kind)} • ${_date(task.dueDate)}',
          detail: task.description,
          icon: task.kind == TaskKind.exam ? Icons.quiz_outlined : Icons.task_alt_outlined,
          score: relevance + (task.status == TaskStatus.done ? 0 : 5),
          timestamp: task.dueDate,
          onTap: () => showTaskEditor(context, state, task: task),
          onAttachments: task.id == null
              ? null
              : () => showAttachmentManager(
                    context,
                    target: AttachmentTarget(type: AttachmentTargetType.task, id: task.id!, subjectId: task.subjectId),
                    title: task.title,
                  ),
        ));
      }
    }

    if (enabled(_SearchType.notes)) {
      for (final note in state.notes) {
        if (!subjectEnabled(note.subjectId)) continue;
        final relevance = score([note.title, note.content, note.tags, note.link, state.subjectName(note.subjectId)]);
        if (q.isNotEmpty && relevance < 0) continue;
        hits.add(_SearchHit(
          type: _SearchType.notes,
          title: note.title,
          subtitle: '${state.subjectName(note.subjectId)}${note.tags.trim().isEmpty ? '' : ' • ${note.tags}'}',
          detail: note.content,
          icon: note.pinned ? Icons.push_pin_rounded : Icons.note_alt_outlined,
          score: relevance + (note.pinned ? 12 : 0),
          timestamp: note.createdAt,
          onTap: () => showNoteEditor(context, state, note: note),
          onAttachments: note.id == null
              ? null
              : () => showAttachmentManager(
                    context,
                    target: AttachmentTarget(type: AttachmentTargetType.note, id: note.id!, subjectId: note.subjectId),
                    title: note.title,
                  ),
        ));
      }
    }

    if (enabled(_SearchType.materials)) {
      for (final material in state.materials) {
        if (!subjectEnabled(material.subjectId)) continue;
        final relevance = score([material.title, material.description, material.url, materialKindLabel(material.kind), state.subjectName(material.subjectId)]);
        if (q.isNotEmpty && relevance < 0) continue;
        hits.add(_SearchHit(
          type: _SearchType.materials,
          title: material.title,
          subtitle: '${state.subjectName(material.subjectId)} • ${materialKindLabel(material.kind)}',
          detail: material.description.isNotEmpty ? material.description : material.url,
          icon: Icons.folder_open_outlined,
          score: relevance,
          timestamp: material.createdAt,
          onTap: () => showMaterialEditor(context, state, material: material),
          onAttachments: material.id == null
              ? null
              : () => showAttachmentManager(
                    context,
                    target: AttachmentTarget(type: AttachmentTargetType.material, id: material.id!, subjectId: material.subjectId),
                    title: material.title,
                  ),
        ));
      }
    }

    if (enabled(_SearchType.classes)) {
      for (final session in state.classSessions) {
        if (session.id == null || !subjectEnabled(session.subjectId)) continue;
        final relevance = score([state.subjectName(session.subjectId), session.room, session.note, _date(session.date), session.start, session.end]);
        if (q.isNotEmpty && relevance < 0) continue;
        hits.add(_SearchHit(
          type: _SearchType.classes,
          title: state.subjectName(session.subjectId),
          subtitle: '${_date(session.date)} • ${session.start}–${session.end}',
          detail: session.note,
          icon: Icons.schedule_rounded,
          score: relevance,
          timestamp: session.startsAt,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ClassDetailScreen(sessionId: session.id!))),
          onAttachments: () => showAttachmentManager(
            context,
            target: AttachmentTarget(type: AttachmentTargetType.classSession, id: session.id!, subjectId: session.subjectId),
            title: '${state.subjectName(session.subjectId)} • ${_date(session.date)}',
          ),
        ));
      }
    }

    if (enabled(_SearchType.attachments)) {
      for (final item in attachments) {
        if (!subjectEnabled(item.subjectId)) continue;
        final relevance = score([
          item.title,
          item.fileName,
          attachmentKindLabel(item.kind),
          attachmentTargetLabel(item.targetType),
          state.subjectName(item.subjectId),
        ]);
        if (q.isNotEmpty && relevance < 0) continue;
        hits.add(_SearchHit(
          type: _SearchType.attachments,
          title: item.title,
          subtitle: '${state.subjectName(item.subjectId)} • ${attachmentTargetLabel(item.targetType)} • ${attachmentKindLabel(item.kind)}',
          detail: item.fileName,
          icon: _attachmentIcon(item.kind),
          score: relevance + 4,
          timestamp: item.createdAt,
          onTap: () => showAttachmentManager(context, target: item.target, title: item.title),
        ));
      }
    }

    if (q.isNotEmpty) {
      hits.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        return (b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0));
      });
      return hits.take(80).toList();
    }

    final visible = hits.where((hit) => hit.type != _SearchType.classes || type == _SearchType.classes).toList();
    visible.sort((a, b) => (b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0)));
    return visible.take(24).toList();
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.type, required this.subjectFilter, required this.onTypeChanged, required this.onSubjectChanged});
  final AppState state;
  final _SearchType type;
  final int? subjectFilter;
  final ValueChanged<_SearchType> onTypeChanged;
  final ValueChanged<int?> onSubjectChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          children: [
            for (final item in _SearchType.values) ...[
              ChoiceChip(selected: type == item, avatar: Icon(_typeIcon(item), size: 16), label: Text(_typeLabel(item)), onSelected: (_) => onTypeChanged(item)),
              const SizedBox(width: 7),
            ],
            const SizedBox(width: 4),
            DropdownButton<int?>(
              value: subjectFilter,
              hint: const Text('Todas as matérias'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todas as matérias')),
                ...state.subjects.map((subject) => DropdownMenuItem<int?>(value: subject.id, child: Text(subject.name))),
              ],
              onChanged: onSubjectChanged,
            ),
          ],
        ),
      );
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.hit});
  final _SearchHit hit;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          onTap: hit.onTap,
          leading: CircleAvatar(child: Icon(hit.icon, size: 20)),
          title: Text(hit.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(hit.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
              if (hit.detail.trim().isNotEmpty)
                Text(hit.detail.trim().replaceAll('\n', ' '), maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          trailing: hit.onAttachments == null
              ? Icon(_typeIcon(hit.type), size: 18)
              : IconButton(tooltip: 'Anexos', onPressed: hit.onAttachments, icon: const Icon(Icons.attach_file_rounded)),
        ),
      );
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.searching});
  final bool searching;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(searching ? Icons.search_off_rounded : Icons.manage_search_rounded, size: 54),
              const SizedBox(height: 12),
              Text(searching ? 'Nenhum resultado encontrado' : 'Nada para mostrar ainda', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(searching ? 'Tente outras palavras ou remova algum filtro. A busca ignora diferenças de acentuação.' : 'Crie conteúdos acadêmicos para usar a busca avançada.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}

class _SearchHit {
  const _SearchHit({required this.type, required this.title, required this.subtitle, this.detail = '', required this.icon, required this.score, required this.timestamp, required this.onTap, this.onAttachments});
  final _SearchType type;
  final String title;
  final String subtitle;
  final String detail;
  final IconData icon;
  final int score;
  final DateTime? timestamp;
  final VoidCallback onTap;
  final VoidCallback? onAttachments;
}

String _typeLabel(_SearchType type) => switch (type) {
      _SearchType.all => 'Tudo',
      _SearchType.subjects => 'Matérias',
      _SearchType.tasks => 'Atividades',
      _SearchType.notes => 'Anotações',
      _SearchType.materials => 'Materiais',
      _SearchType.classes => 'Aulas',
      _SearchType.attachments => 'Anexos',
    };

IconData _typeIcon(_SearchType type) => switch (type) {
      _SearchType.all => Icons.apps_rounded,
      _SearchType.subjects => Icons.auto_stories_outlined,
      _SearchType.tasks => Icons.task_alt_outlined,
      _SearchType.notes => Icons.note_alt_outlined,
      _SearchType.materials => Icons.folder_open_outlined,
      _SearchType.classes => Icons.schedule_rounded,
      _SearchType.attachments => Icons.attach_file_rounded,
    };

IconData _attachmentIcon(AttachmentKind kind) => switch (kind) {
      AttachmentKind.image => Icons.image_outlined,
      AttachmentKind.pdf => Icons.picture_as_pdf_outlined,
      AttachmentKind.document => Icons.description_outlined,
      AttachmentKind.archive => Icons.folder_zip_outlined,
      AttachmentKind.other => Icons.insert_drive_file_outlined,
    };

String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
