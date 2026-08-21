import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../utils/search_engine.dart';
import '../widgets/v22_actions.dart';
import 'class_detail_screen.dart';
import 'subject_detail_screen.dart';

enum _SearchType { all, subjects, tasks, notes, materials, classes }

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final controller = TextEditingController();
  String query = '';
  _SearchType type = _SearchType.all;
  int? subjectFilter;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final hits = _results(state);
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
                hintText: 'Busque por palavras, matéria, tag, professor, link...',
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
                    searching
                        ? '${hits.length} resultado${hits.length == 1 ? '' : 's'} por relevância'
                        : 'Itens recentes e úteis',
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
  }

  List<_SearchHit> _results(AppState state) {
    final q = query.trim();
    final hits = <_SearchHit>[];

    bool typeEnabled(_SearchType candidate) => type == _SearchType.all || type == candidate;
    bool subjectEnabled(int? subjectId) => subjectFilter == null || subjectId == subjectFilter;
    int score(List<String> fields) => q.isEmpty ? 0 : searchScore(q, fields);

    if (typeEnabled(_SearchType.subjects)) {
      for (final subject in state.subjects) {
        if (subject.id == null || !subjectEnabled(subject.id)) continue;
        final relevance = score([subject.name, subject.professor, subject.room]);
        if (q.isNotEmpty && relevance < 0) continue;
        hits.add(
          _SearchHit(
            type: _SearchType.subjects,
            title: subject.name,
            subtitle: [
              if (subject.professor.isNotEmpty) subject.professor,
              if (subject.room.isNotEmpty) subject.room,
              'Frequência ${subject.attendance.toStringAsFixed(1)}%',
            ].join(' • '),
            icon: Icons.auto_stories_outlined,
            score: relevance + 8,
            timestamp: null,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SubjectDetailScreen(subjectId: subject.id!)),
            ),
          ),
        );
      }
    }

    if (typeEnabled(_SearchType.tasks)) {
      for (final task in state.tasks) {
        if (!subjectEnabled(task.subjectId)) continue;
        final relevance = score([
          task.title,
          task.description,
          task.checklist.join(' '),
          state.subjectName(task.subjectId),
          taskKindLabel(task.kind),
          _taskStatus(task.status),
          _priority(task.priority),
        ]);
        if (q.isNotEmpty && relevance < 0) continue;
        final pendingBoost = task.status == TaskStatus.done ? 0 : 5;
        hits.add(
          _SearchHit(
            type: _SearchType.tasks,
            title: task.title,
            subtitle: '${state.subjectName(task.subjectId)} • ${taskKindLabel(task.kind)} • ${_date(task.dueDate)}',
            detail: task.description,
            icon: task.kind == TaskKind.exam ? Icons.quiz_outlined : Icons.task_alt_outlined,
            score: relevance + pendingBoost,
            timestamp: task.dueDate,
            onTap: () => showTaskEditor(context, state, task: task),
          ),
        );
      }
    }

    if (typeEnabled(_SearchType.notes)) {
      for (final note in state.notes) {
        if (!subjectEnabled(note.subjectId)) continue;
        final relevance = score([
          note.title,
          note.content,
          note.tags,
          note.link,
          state.subjectName(note.subjectId),
        ]);
        if (q.isNotEmpty && relevance < 0) continue;
        hits.add(
          _SearchHit(
            type: _SearchType.notes,
            title: note.title,
            subtitle: '${state.subjectName(note.subjectId)}${note.tags.trim().isEmpty ? '' : ' • ${note.tags}'}',
            detail: note.content,
            icon: note.pinned ? Icons.push_pin_rounded : Icons.note_alt_outlined,
            score: relevance + (note.pinned ? 12 : 0),
            timestamp: note.createdAt,
            onTap: () => showNoteEditor(context, state, note: note),
          ),
        );
      }
    }

    if (typeEnabled(_SearchType.materials)) {
      for (final material in state.materials) {
        if (!subjectEnabled(material.subjectId)) continue;
        final relevance = score([
          material.title,
          material.description,
          material.url,
          materialKindLabel(material.kind),
          state.subjectName(material.subjectId),
        ]);
        if (q.isNotEmpty && relevance < 0) continue;
        hits.add(
          _SearchHit(
            type: _SearchType.materials,
            title: material.title,
            subtitle: '${state.subjectName(material.subjectId)} • ${materialKindLabel(material.kind)}',
            detail: material.description.isNotEmpty ? material.description : material.url,
            icon: _materialIcon(material.kind),
            score: relevance,
            timestamp: material.createdAt,
            onTap: () => showMaterialEditor(context, state, material: material),
          ),
        );
      }
    }

    if (typeEnabled(_SearchType.classes)) {
      for (final session in state.classSessions) {
        if (session.id == null || !subjectEnabled(session.subjectId)) continue;
        final relevance = score([
          state.subjectName(session.subjectId),
          session.room,
          session.note,
          _attendanceStatus(session.status),
          _date(session.date),
          session.start,
          session.end,
        ]);
        if (q.isNotEmpty && relevance < 0) continue;
        hits.add(
          _SearchHit(
            type: _SearchType.classes,
            title: state.subjectName(session.subjectId),
            subtitle: '${_date(session.date)} • ${session.start}–${session.end} • ${_attendanceStatus(session.status)}',
            detail: session.note,
            icon: Icons.schedule_rounded,
            score: relevance,
            timestamp: session.startsAt,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ClassDetailScreen(sessionId: session.id!)),
            ),
          ),
        );
      }
    }

    if (q.isNotEmpty) {
      hits.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return hits.take(80).toList();
    }

    hits.sort((a, b) {
      if (a.type == _SearchType.notes && a.score > b.score) return -1;
      final aTime = a.timestamp ?? DateTime.now().subtract(const Duration(days: 36500));
      final bTime = b.timestamp ?? DateTime.now().subtract(const Duration(days: 36500));
      return bTime.compareTo(aTime);
    });
    return hits.take(24).toList();
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.state,
    required this.type,
    required this.subjectFilter,
    required this.onTypeChanged,
    required this.onSubjectChanged,
  });

  final AppState state;
  final _SearchType type;
  final int? subjectFilter;
  final ValueChanged<_SearchType> onTypeChanged;
  final ValueChanged<int?> onSubjectChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          for (final item in _SearchType.values) ...[
            ChoiceChip(
              selected: type == item,
              avatar: Icon(_typeIcon(item), size: 16),
              label: Text(_typeLabel(item)),
              onSelected: (_) => onTypeChanged(item),
            ),
            const SizedBox(width: 7),
          ],
          const SizedBox(width: 4),
          DropdownButton<int?>(
            value: subjectFilter,
            hint: const Text('Todas as matérias'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Todas as matérias')),
              ...state.subjects.map(
                (subject) => DropdownMenuItem<int?>(value: subject.id, child: Text(subject.name)),
              ),
            ],
            onChanged: onSubjectChanged,
          ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.hit});

  final _SearchHit hit;

  @override
  Widget build(BuildContext context) {
    return Card(
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
              Text(
                hit.detail.trim().replaceAll('\n', ' '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_typeIcon(hit.type), size: 16),
            const SizedBox(height: 3),
            Text(_typeShortLabel(hit.type), style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.searching});

  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(searching ? Icons.search_off_rounded : Icons.manage_search_rounded, size: 54),
            const SizedBox(height: 12),
            Text(
              searching ? 'Nenhum resultado encontrado' : 'Nada para mostrar ainda',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              searching
                  ? 'Tente outras palavras ou remova algum filtro. A busca ignora diferenças de acentuação.'
                  : 'Crie matérias, tarefas, anotações e materiais para usar a busca avançada.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchHit {
  const _SearchHit({
    required this.type,
    required this.title,
    required this.subtitle,
    this.detail = '',
    required this.icon,
    required this.score,
    required this.timestamp,
    required this.onTap,
  });

  final _SearchType type;
  final String title;
  final String subtitle;
  final String detail;
  final IconData icon;
  final int score;
  final DateTime? timestamp;
  final VoidCallback onTap;
}

String _typeLabel(_SearchType type) => switch (type) {
      _SearchType.all => 'Tudo',
      _SearchType.subjects => 'Matérias',
      _SearchType.tasks => 'Atividades',
      _SearchType.notes => 'Anotações',
      _SearchType.materials => 'Materiais',
      _SearchType.classes => 'Aulas',
    };

String _typeShortLabel(_SearchType type) => switch (type) {
      _SearchType.all => 'Tudo',
      _SearchType.subjects => 'Matéria',
      _SearchType.tasks => 'Prazo',
      _SearchType.notes => 'Nota',
      _SearchType.materials => 'Material',
      _SearchType.classes => 'Aula',
    };

IconData _typeIcon(_SearchType type) => switch (type) {
      _SearchType.all => Icons.apps_rounded,
      _SearchType.subjects => Icons.auto_stories_outlined,
      _SearchType.tasks => Icons.task_alt_outlined,
      _SearchType.notes => Icons.note_alt_outlined,
      _SearchType.materials => Icons.folder_open_outlined,
      _SearchType.classes => Icons.schedule_rounded,
    };

IconData _materialIcon(MaterialKind kind) => switch (kind) {
      MaterialKind.pdf => Icons.picture_as_pdf_rounded,
      MaterialKind.slides => Icons.slideshow_rounded,
      MaterialKind.video => Icons.play_circle_outline_rounded,
      MaterialKind.link => Icons.link_rounded,
      MaterialKind.repository => Icons.code_rounded,
      MaterialKind.document => Icons.description_outlined,
      MaterialKind.other => Icons.attach_file_rounded,
    };

String _taskStatus(TaskStatus status) => switch (status) {
      TaskStatus.todo => 'A fazer',
      TaskStatus.doing => 'Em andamento',
      TaskStatus.done => 'Concluído',
    };

String _priority(Priority priority) => switch (priority) {
      Priority.high => 'Prioridade alta',
      Priority.medium => 'Prioridade média',
      Priority.low => 'Prioridade baixa',
    };

String _attendanceStatus(AttendanceStatus status) => switch (status) {
      AttendanceStatus.pending => 'Pendente',
      AttendanceStatus.present => 'Presente',
      AttendanceStatus.absent => 'Falta',
      AttendanceStatus.cancelled => 'Cancelada',
    };

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
