import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/search_engine.dart';
import '../widgets/v22_actions.dart';

enum _LibrarySort { recent, title, subject }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  final searchController = TextEditingController();
  String query = '';
  int? subjectFilter;
  String? tagFilter;
  MaterialKind? materialKindFilter;
  bool pinnedOnly = false;
  _LibrarySort sort = _LibrarySort.recent;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this)..addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!tabs.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    tabs
      ..removeListener(_onTabChanged)
      ..dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final tags = _allTags(state);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca acadêmica'),
        bottom: TabBar(
          controller: tabs,
          tabs: [
            Tab(text: 'Anotações (${state.notes.length})'),
            Tab(text: 'Materiais (${state.materials.length})'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: tabs.index == 0 ? 'Nova anotação' : 'Novo material',
            icon: const Icon(Icons.add_rounded),
            onPressed: () => tabs.index == 0 ? showNoteEditor(context, state) : showMaterialEditor(context, state),
          ),
        ],
      ),
      body: Column(
        children: [
          _LibraryToolbar(
            controller: searchController,
            query: query,
            subjects: state.subjects,
            subjectFilter: subjectFilter,
            sort: sort,
            onQueryChanged: (value) => setState(() => query = value),
            onClearQuery: () {
              searchController.clear();
              setState(() => query = '');
            },
            onSubjectChanged: (value) => setState(() => subjectFilter = value),
            onSortChanged: (value) => setState(() => sort = value),
          ),
          AnimatedBuilder(
            animation: tabs,
            builder: (context, _) {
              if (tabs.index == 0) {
                return _NoteFilters(
                  tags: tags,
                  selectedTag: tagFilter,
                  pinnedOnly: pinnedOnly,
                  onTagChanged: (value) => setState(() => tagFilter = value),
                  onPinnedChanged: (value) => setState(() => pinnedOnly = value),
                );
              }
              return _MaterialFilters(
                selected: materialKindFilter,
                onChanged: (value) => setState(() => materialKindFilter = value),
              );
            },
          ),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: [
                _notes(state),
                _materials(state),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => tabs.index == 0 ? showNoteEditor(context, state) : showMaterialEditor(context, state),
        icon: const Icon(Icons.add_rounded),
        label: Text(tabs.index == 0 ? 'Anotação' : 'Material'),
      ),
    );
  }

  Widget _notes(AppState state) {
    final items = state.notes.where((note) {
      if (subjectFilter != null && note.subjectId != subjectFilter) return false;
      if (pinnedOnly && !note.pinned) return false;
      if (tagFilter != null && !_noteTags(note).contains(tagFilter)) return false;
      return query.trim().isEmpty ||
          matchesSearch(query, [
            note.title,
            note.content,
            note.tags,
            note.link,
            state.subjectName(note.subjectId),
          ]);
    }).toList();

    items.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return _compareLibraryItems(
        aTitle: a.title,
        bTitle: b.title,
        aSubject: state.subjectName(a.subjectId),
        bSubject: state.subjectName(b.subjectId),
        aCreated: a.createdAt,
        bCreated: b.createdAt,
      );
    });

    if (items.isEmpty) {
      return _empty(
        Icons.note_alt_outlined,
        query.isNotEmpty || subjectFilter != null || tagFilter != null || pinnedOnly
            ? 'Nenhuma anotação encontrada'
            : 'Nenhuma anotação',
        query.isNotEmpty || subjectFilter != null || tagFilter != null || pinnedOnly
            ? 'Ajuste a busca ou remova algum filtro.'
            : 'Guarde resumos, lembretes, tópicos de revisão e links.',
        () => showNoteEditor(context, state),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final note = items[i];
        final tags = _noteTags(note);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showNoteEditor(context, state, note: note),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (note.pinned)
                        const Padding(
                          padding: EdgeInsets.only(right: 7),
                          child: Icon(Icons.push_pin_rounded, size: 17, color: AppColors.gold),
                        ),
                      Expanded(
                        child: Text(
                          note.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        tooltip: note.pinned ? 'Desafixar' : 'Fixar',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _toggleNotePin(state, note),
                        icon: Icon(note.pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') await showNoteEditor(context, state, note: note);
                          if (value == 'open') await _openUrl(note.link);
                          if (value == 'delete' && await confirmDelete(context, note.title)) {
                            await state.deleteNote(note);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('Editar')),
                          if (_canOpen(note.link)) const PopupMenuItem(value: 'open', child: Text('Abrir link')),
                          const PopupMenuDivider(),
                          const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${state.subjectName(note.subjectId)} • ${_formatDate(note.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Text(note.content, maxLines: 4, overflow: TextOverflow.ellipsis),
                  ],
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tags)
                          ActionChip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() => tagFilter = tag),
                          ),
                      ],
                    ),
                  ],
                  if (_canOpen(note.link)) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => _openUrl(note.link),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Abrir link relacionado'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _materials(AppState state) {
    final items = state.materials.where((material) {
      if (subjectFilter != null && material.subjectId != subjectFilter) return false;
      if (materialKindFilter != null && material.kind != materialKindFilter) return false;
      return query.trim().isEmpty ||
          matchesSearch(query, [
            material.title,
            material.description,
            material.url,
            materialKindLabel(material.kind),
            state.subjectName(material.subjectId),
          ]);
    }).toList();

    items.sort((a, b) => _compareLibraryItems(
          aTitle: a.title,
          bTitle: b.title,
          aSubject: state.subjectName(a.subjectId),
          bSubject: state.subjectName(b.subjectId),
          aCreated: a.createdAt,
          bCreated: b.createdAt,
        ));

    if (items.isEmpty) {
      return _empty(
        Icons.folder_open_rounded,
        query.isNotEmpty || subjectFilter != null || materialKindFilter != null
            ? 'Nenhum material encontrado'
            : 'Nenhum material',
        query.isNotEmpty || subjectFilter != null || materialKindFilter != null
            ? 'Ajuste a busca ou remova algum filtro.'
            : 'Organize PDFs, slides, vídeos, links, documentos e repositórios.',
        state.subjects.isEmpty ? null : () => showMaterialEditor(context, state),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final material = items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              leading: CircleAvatar(
                backgroundColor: AppColors.gold.withValues(alpha: .12),
                child: Icon(_icon(material.kind), color: AppColors.gold),
              ),
              title: Text(material.title, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(
                '${materialKindLabel(material.kind)} • ${state.subjectName(material.subjectId)} • ${_formatDate(material.createdAt)}'
                '${material.description.isEmpty ? '' : '\n${material.description}'}',
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => showMaterialEditor(context, state, material: material),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_canOpen(material.url))
                    IconButton(
                      tooltip: 'Abrir material',
                      onPressed: () => _openUrl(material.url),
                      icon: const Icon(Icons.open_in_new_rounded),
                    ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') await showMaterialEditor(context, state, material: material);
                      if (value == 'open') await _openUrl(material.url);
                      if (value == 'delete' && await confirmDelete(context, material.title)) {
                        await state.deleteMaterial(material);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('Editar')),
                      if (_canOpen(material.url)) const PopupMenuItem(value: 'open', child: Text('Abrir material')),
                      const PopupMenuDivider(),
                      const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  int _compareLibraryItems({
    required String aTitle,
    required String bTitle,
    required String aSubject,
    required String bSubject,
    required DateTime aCreated,
    required DateTime bCreated,
  }) {
    return switch (sort) {
      _LibrarySort.recent => bCreated.compareTo(aCreated),
      _LibrarySort.title => aTitle.toLowerCase().compareTo(bTitle.toLowerCase()),
      _LibrarySort.subject => aSubject.toLowerCase().compareTo(bSubject.toLowerCase()),
    };
  }

  List<String> _allTags(AppState state) {
    final tags = <String>{};
    for (final note in state.notes) {
      tags.addAll(_noteTags(note));
    }
    final list = tags.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> _noteTags(AcademicNote note) => note.tags
      .split(',')
      .map((tag) => tag.trim())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList();

  Future<void> _toggleNotePin(AppState state, AcademicNote note) async {
    await state.saveNote(
      AcademicNote(
        id: note.id,
        subjectId: note.subjectId,
        title: note.title,
        content: note.content,
        link: note.link,
        tags: note.tags,
        pinned: !note.pinned,
        createdAt: note.createdAt,
        sessionId: note.sessionId,
      ),
    );
  }

  bool _canOpen(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value.trim());
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir este link.')),
      );
    }
  }

  Widget _empty(IconData icon, String title, String message, VoidCallback? action) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 50),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(message, textAlign: TextAlign.center),
              if (action != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: action,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Adicionar'),
                ),
              ],
            ],
          ),
        ),
      );

  IconData _icon(MaterialKind kind) => switch (kind) {
        MaterialKind.pdf => Icons.picture_as_pdf_rounded,
        MaterialKind.slides => Icons.slideshow_rounded,
        MaterialKind.video => Icons.play_circle_outline_rounded,
        MaterialKind.repository => Icons.code_rounded,
        MaterialKind.document => Icons.description_outlined,
        MaterialKind.other => Icons.attach_file_rounded,
        MaterialKind.link => Icons.link_rounded,
      };
}

class _LibraryToolbar extends StatelessWidget {
  const _LibraryToolbar({
    required this.controller,
    required this.query,
    required this.subjects,
    required this.subjectFilter,
    required this.sort,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onSubjectChanged,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final String query;
  final List<Subject> subjects;
  final int? subjectFilter;
  final _LibrarySort sort;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<int?> onSubjectChanged;
  final ValueChanged<_LibrarySort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              hintText: 'Buscar título, conteúdo, tag, matéria ou link...',
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpar busca',
                      onPressed: onClearQuery,
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
          const SizedBox(height: 9),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                DropdownButton<int?>(
                  value: subjectFilter,
                  hint: const Text('Todas as matérias'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Todas as matérias')),
                    ...subjects.map((subject) => DropdownMenuItem<int?>(value: subject.id, child: Text(subject.name))),
                  ],
                  onChanged: onSubjectChanged,
                ),
                const SizedBox(width: 18),
                DropdownButton<_LibrarySort>(
                  value: sort,
                  items: const [
                    DropdownMenuItem(value: _LibrarySort.recent, child: Text('Mais recentes')),
                    DropdownMenuItem(value: _LibrarySort.title, child: Text('Título A–Z')),
                    DropdownMenuItem(value: _LibrarySort.subject, child: Text('Por matéria')),
                  ],
                  onChanged: (value) {
                    if (value != null) onSortChanged(value);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteFilters extends StatelessWidget {
  const _NoteFilters({
    required this.tags,
    required this.selectedTag,
    required this.pinnedOnly,
    required this.onTagChanged,
    required this.onPinnedChanged,
  });

  final List<String> tags;
  final String? selectedTag;
  final bool pinnedOnly;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<bool> onPinnedChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        children: [
          FilterChip(
            selected: pinnedOnly,
            avatar: const Icon(Icons.push_pin_outlined, size: 16),
            label: const Text('Fixadas'),
            onSelected: onPinnedChanged,
          ),
          const SizedBox(width: 7),
          ChoiceChip(
            selected: selectedTag == null,
            label: const Text('Todas as tags'),
            onSelected: (_) => onTagChanged(null),
          ),
          for (final tag in tags) ...[
            const SizedBox(width: 7),
            ChoiceChip(
              selected: selectedTag == tag,
              label: Text('#$tag'),
              onSelected: (_) => onTagChanged(selectedTag == tag ? null : tag),
            ),
          ],
        ],
      ),
    );
  }
}

class _MaterialFilters extends StatelessWidget {
  const _MaterialFilters({required this.selected, required this.onChanged});

  final MaterialKind? selected;
  final ValueChanged<MaterialKind?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        children: [
          ChoiceChip(
            selected: selected == null,
            label: const Text('Todos os tipos'),
            onSelected: (_) => onChanged(null),
          ),
          for (final kind in MaterialKind.values) ...[
            const SizedBox(width: 7),
            ChoiceChip(
              selected: selected == kind,
              label: Text(materialKindLabel(kind)),
              onSelected: (_) => onChanged(selected == kind ? null : kind),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
