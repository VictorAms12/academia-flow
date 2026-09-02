import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/attachment.dart';
import '../models/models.dart';
import '../services/attachment_repository.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/search_engine.dart';
import '../widgets/v22_actions.dart';
import 'attachment_manager_screen.dart';

enum _LibrarySort { recent, title, subject }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  final searchController = TextEditingController();
  final attachments = AttachmentRepository.instance;

  String query = '';
  int? subjectFilter;
  String? tagFilter;
  MaterialKind? materialKindFilter;
  AttachmentKind? attachmentKindFilter;
  bool pinnedOnly = false;
  _LibrarySort sort = _LibrarySort.recent;
  late Future<List<AcademicAttachment>> attachmentFuture;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this)..addListener(_tabChanged);
    attachmentFuture = attachments.allAttachments();
  }

  void _tabChanged() {
    if (!tabs.indexIsChanging && mounted) setState(() {});
  }

  Future<void> _reloadAttachments() async {
    if (!mounted) return;
    setState(() => attachmentFuture = attachments.allAttachments());
  }

  @override
  void dispose() {
    tabs
      ..removeListener(_tabChanged)
      ..dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final allTags = <String>{
      for (final note in state.notes)
        ...note.tags.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca acadêmica'),
        bottom: TabBar(
          controller: tabs,
          tabs: [
            Tab(text: 'Anotações (${state.notes.length})'),
            Tab(text: 'Materiais (${state.materials.length})'),
            const Tab(text: 'Anexos'),
          ],
        ),
        actions: [
          if (tabs.index < 2)
            IconButton(
              tooltip: tabs.index == 0 ? 'Nova anotação' : 'Novo material',
              onPressed: () => tabs.index == 0 ? showNoteEditor(context, state) : showMaterialEditor(context, state),
              icon: const Icon(Icons.add_rounded),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: TextField(
              controller: searchController,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: tabs.index == 2 ? 'Buscar fotos e arquivos...' : 'Buscar na biblioteca...',
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar',
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          _commonFilters(state),
          if (tabs.index == 0) _noteFilters(allTags),
          if (tabs.index == 1) _materialFilters(),
          if (tabs.index == 2) _attachmentFilters(),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: [
                _notes(state),
                _materials(state),
                _attachments(state),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: tabs.index < 2
          ? FloatingActionButton.extended(
              onPressed: () => tabs.index == 0 ? showNoteEditor(context, state) : showMaterialEditor(context, state),
              icon: const Icon(Icons.add_rounded),
              label: Text(tabs.index == 0 ? 'Anotação' : 'Material'),
            )
          : null,
    );
  }

  Widget _commonFilters(AppState state) {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          DropdownButton<int?>(
            value: subjectFilter,
            hint: const Text('Todas as matérias'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Todas as matérias')),
              ...state.subjects.map((subject) => DropdownMenuItem<int?>(value: subject.id, child: Text(subject.name))),
            ],
            onChanged: (value) => setState(() => subjectFilter = value),
          ),
          const SizedBox(width: 14),
          PopupMenuButton<_LibrarySort>(
            tooltip: 'Ordenar',
            onSelected: (value) => setState(() => sort = value),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _LibrarySort.recent, child: Text('Mais recentes')),
              PopupMenuItem(value: _LibrarySort.title, child: Text('Título A–Z')),
              PopupMenuItem(value: _LibrarySort.subject, child: Text('Matéria')),
            ],
            child: Chip(
              avatar: const Icon(Icons.sort_rounded, size: 17),
              label: Text(switch (sort) {
                _LibrarySort.recent => 'Recentes',
                _LibrarySort.title => 'Título',
                _LibrarySort.subject => 'Matéria',
              }),
            ),
          ),
          if (query.isNotEmpty || subjectFilter != null || tagFilter != null || pinnedOnly || materialKindFilter != null || attachmentKindFilter != null) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.filter_alt_off_outlined, size: 17),
              label: const Text('Limpar filtros'),
              onPressed: () {
                searchController.clear();
                setState(() {
                  query = '';
                  subjectFilter = null;
                  tagFilter = null;
                  pinnedOnly = false;
                  materialKindFilter = null;
                  attachmentKindFilter = null;
                });
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _noteFilters(List<String> tags) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        children: [
          FilterChip(
            selected: pinnedOnly,
            avatar: const Icon(Icons.push_pin_outlined, size: 16),
            label: const Text('Fixadas'),
            onSelected: (value) => setState(() => pinnedOnly = value),
          ),
          for (final tag in tags) ...[
            const SizedBox(width: 6),
            FilterChip(
              selected: tagFilter == tag,
              label: Text(tag),
              onSelected: (selected) => setState(() => tagFilter = selected ? tag : null),
            ),
          ],
        ],
      ),
    );
  }

  Widget _materialFilters() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        children: [
          ChoiceChip(
            selected: materialKindFilter == null,
            label: const Text('Todos'),
            onSelected: (_) => setState(() => materialKindFilter = null),
          ),
          for (final kind in MaterialKind.values) ...[
            const SizedBox(width: 6),
            ChoiceChip(
              selected: materialKindFilter == kind,
              label: Text(materialKindLabel(kind)),
              onSelected: (_) => setState(() => materialKindFilter = kind),
            ),
          ],
        ],
      ),
    );
  }

  Widget _attachmentFilters() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
        children: [
          ChoiceChip(
            selected: attachmentKindFilter == null,
            label: const Text('Todos'),
            onSelected: (_) => setState(() => attachmentKindFilter = null),
          ),
          for (final kind in AttachmentKind.values) ...[
            const SizedBox(width: 6),
            ChoiceChip(
              selected: attachmentKindFilter == kind,
              label: Text(attachmentKindLabel(kind)),
              onSelected: (_) => setState(() => attachmentKindFilter = kind),
            ),
          ],
        ],
      ),
    );
  }

  Widget _notes(AppState state) {
    final items = state.notes.where((note) {
      if (subjectFilter != null && note.subjectId != subjectFilter) return false;
      if (pinnedOnly && !note.pinned) return false;
      final tags = note.tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      if (tagFilter != null && !tags.contains(tagFilter)) return false;
      return query.trim().isEmpty ||
          matchesSearch(query, [note.title, note.content, note.tags, note.link, state.subjectName(note.subjectId)]);
    }).toList();

    items.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return _compare(
        a.title,
        b.title,
        state.subjectName(a.subjectId),
        state.subjectName(b.subjectId),
        a.createdAt,
        b.createdAt,
      );
    });

    if (items.isEmpty) return _empty('Nenhuma anotação encontrada', Icons.note_alt_outlined);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final note = items[index];
        final noteTags = note.tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () => showNoteEditor(context, state, note: note),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (note.pinned) const Icon(Icons.push_pin_rounded, size: 17, color: AppColors.gold),
                      if (note.pinned) const SizedBox(width: 6),
                      Expanded(child: Text(note.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                      if (note.id != null)
                        IconButton(
                          tooltip: 'Anexos',
                          onPressed: () async {
                            await showAttachmentManager(
                              context,
                              target: AttachmentTarget(type: AttachmentTargetType.note, id: note.id!, subjectId: note.subjectId),
                              title: note.title,
                            );
                            await _reloadAttachments();
                          },
                          icon: const Icon(Icons.attach_file_rounded),
                        ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'pin') {
                            await state.saveNote(AcademicNote(
                              id: note.id,
                              subjectId: note.subjectId,
                              title: note.title,
                              content: note.content,
                              link: note.link,
                              tags: note.tags,
                              pinned: !note.pinned,
                              createdAt: note.createdAt,
                              sessionId: note.sessionId,
                            ));
                          }
                          if (value == 'open' && _canOpen(note.link)) await launchUrl(Uri.parse(note.link), mode: LaunchMode.externalApplication);
                          if (!context.mounted) return;
                          if (value == 'delete' && await confirmDelete(context, note.title)) await state.deleteNote(note);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(value: 'pin', child: Text(note.pinned ? 'Desafixar' : 'Fixar')),
                          if (_canOpen(note.link)) const PopupMenuItem(value: 'open', child: Text('Abrir link')),
                          const PopupMenuDivider(),
                          const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                        ],
                      ),
                    ],
                  ),
                  Text('${state.subjectName(note.subjectId)} • ${_date(note.createdAt)}', style: Theme.of(context).textTheme.bodySmall),
                  if (note.content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(note.content, maxLines: 4, overflow: TextOverflow.ellipsis),
                  ],
                  if (noteTags.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        for (final tag in noteTags)
                          ActionChip(
                            visualDensity: VisualDensity.compact,
                            label: Text(tag),
                            onPressed: () => setState(() => tagFilter = tag),
                          ),
                      ],
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
          matchesSearch(query, [material.title, material.description, material.url, materialKindLabel(material.kind), state.subjectName(material.subjectId)]);
    }).toList();

    items.sort((a, b) => _compare(
          a.title,
          b.title,
          state.subjectName(a.subjectId),
          state.subjectName(b.subjectId),
          a.createdAt,
          b.createdAt,
        ));

    if (items.isEmpty) return _empty('Nenhum material encontrado', Icons.folder_open_outlined);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final material = items[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(
              backgroundColor: AppColors.gold.withValues(alpha: .10),
              child: Icon(_materialIcon(material.kind), color: AppColors.gold),
            ),
            title: Text(material.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text(
              '${state.subjectName(material.subjectId)} • ${materialKindLabel(material.kind)}${material.description.isEmpty ? '' : '\n${material.description}'}',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => showMaterialEditor(context, state, material: material),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_canOpen(material.url))
                  IconButton(
                    tooltip: 'Abrir link',
                    onPressed: () => launchUrl(Uri.parse(material.url), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new_rounded),
                  ),
                if (material.id != null)
                  IconButton(
                    tooltip: 'Anexos',
                    onPressed: () async {
                      await showAttachmentManager(
                        context,
                        target: AttachmentTarget(
                          type: AttachmentTargetType.material,
                          id: material.id!,
                          subjectId: material.subjectId,
                        ),
                        title: material.title,
                      );
                      await _reloadAttachments();
                    },
                    icon: const Icon(Icons.attach_file_rounded),
                  ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    if (value == 'edit') await showMaterialEditor(context, state, material: material);
                    if (!context.mounted) return;
                    if (value == 'delete' && await confirmDelete(context, material.title)) await state.deleteMaterial(material);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text('Excluir')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _attachments(AppState state) {
    return FutureBuilder<List<AcademicAttachment>>(
      future: attachmentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return _empty('Não foi possível carregar os anexos', Icons.error_outline_rounded);
        final items = (snapshot.data ?? const <AcademicAttachment>[]).where((item) {
          if (subjectFilter != null && item.subjectId != subjectFilter) return false;
          if (attachmentKindFilter != null && item.kind != attachmentKindFilter) return false;
          return query.trim().isEmpty ||
              matchesSearch(query, [item.title, item.fileName, attachmentKindLabel(item.kind), state.subjectName(item.subjectId)]);
        }).toList();

        items.sort((a, b) => _compare(
              a.title,
              b.title,
              state.subjectName(a.subjectId),
              state.subjectName(b.subjectId),
              a.createdAt,
              b.createdAt,
            ));

        if (items.isEmpty) return _empty('Nenhum anexo encontrado', Icons.attach_file_rounded);
        return RefreshIndicator(
          onRefresh: _reloadAttachments,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            itemCount: items.length,
            itemBuilder: (_, index) {
              final item = items[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.gold.withValues(alpha: .10),
                    child: Icon(_attachmentIcon(item.kind), color: AppColors.gold),
                  ),
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                  subtitle: Text(
                    '${state.subjectName(item.subjectId)} • ${attachmentTargetLabel(item.targetType)} • ${attachmentKindLabel(item.kind)}\n${item.fileName}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () async {
                    await showAttachmentManager(context, target: item.target, title: item.title);
                    await _reloadAttachments();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _empty(String title, IconData icon) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 50),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              const Text('Ajuste os filtros ou adicione novos conteúdos.', textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  int _compare(String aTitle, String bTitle, String aSubject, String bSubject, DateTime aCreated, DateTime bCreated) => switch (sort) {
        _LibrarySort.recent => bCreated.compareTo(aCreated),
        _LibrarySort.title => aTitle.toLowerCase().compareTo(bTitle.toLowerCase()),
        _LibrarySort.subject => aSubject.toLowerCase().compareTo(bSubject.toLowerCase()),
      };
}

bool _canOpen(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null && (uri.scheme == 'https' || uri.scheme == 'http');
}

String _date(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

IconData _materialIcon(MaterialKind kind) => switch (kind) {
      MaterialKind.pdf => Icons.picture_as_pdf_rounded,
      MaterialKind.slides => Icons.slideshow_rounded,
      MaterialKind.video => Icons.play_circle_outline_rounded,
      MaterialKind.repository => Icons.code_rounded,
      MaterialKind.document => Icons.description_outlined,
      MaterialKind.other => Icons.attach_file_rounded,
      MaterialKind.link => Icons.link_rounded,
    };

IconData _attachmentIcon(AttachmentKind kind) => switch (kind) {
      AttachmentKind.image => Icons.image_outlined,
      AttachmentKind.pdf => Icons.picture_as_pdf_outlined,
      AttachmentKind.document => Icons.description_outlined,
      AttachmentKind.archive => Icons.folder_zip_outlined,
      AttachmentKind.other => Icons.insert_drive_file_outlined,
    };
