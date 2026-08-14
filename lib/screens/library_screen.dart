import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/v22_actions.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  String query = '';

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biblioteca acadêmica'),
        bottom: TabBar(controller: tabs, tabs: const [Tab(text: 'Anotações'), Tab(text: 'Materiais')]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => tabs.index == 0 ? showNoteEditor(context, state) : showMaterialEditor(context, state),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => query = v.toLowerCase()),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Buscar na biblioteca...'),
          ),
        ),
        Expanded(child: TabBarView(controller: tabs, children: [_notes(state), _materials(state)])),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => tabs.index == 0 ? showNoteEditor(context, state) : showMaterialEditor(context, state),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar'),
      ),
    );
  }

  Widget _notes(AppState state) {
    final items = state.notes.where((n) => query.isEmpty || '${n.title} ${n.content} ${n.tags} ${state.subjectName(n.subjectId)}'.toLowerCase().contains(query)).toList();
    if (items.isEmpty) {
      return _empty(Icons.note_alt_outlined, 'Nenhuma anotação', 'Guarde resumos, lembretes, tópicos de revisão e links.', () => showNoteEditor(context, state));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final n = items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showNoteEditor(context, state, note: n),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (n.pinned) const Padding(padding: EdgeInsets.only(right: 7), child: Icon(Icons.push_pin_rounded, size: 17, color: AppColors.gold)),
                  Expanded(child: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'edit') await showNoteEditor(context, state, note: n);
                      if (v == 'delete' && await confirmDelete(context, n.title)) await state.deleteNote(n);
                    },
                    itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Excluir'))],
                  ),
                ]),
                Text(state.subjectName(n.subjectId), style: Theme.of(context).textTheme.bodySmall),
                if (n.content.isNotEmpty) ...[const SizedBox(height: 8), Text(n.content, maxLines: 4, overflow: TextOverflow.ellipsis)],
                if (n.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 6, runSpacing: 6, children: n.tags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).map((e) => Chip(label: Text(e), visualDensity: VisualDensity.compact)).toList()),
                ],
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _materials(AppState state) {
    final items = state.materials.where((m) => query.isEmpty || '${m.title} ${m.description} ${m.url} ${state.subjectName(m.subjectId)}'.toLowerCase().contains(query)).toList();
    if (items.isEmpty) {
      return _empty(Icons.folder_open_rounded, 'Nenhum material', 'Organize PDFs, slides, vídeos, links, documentos e repositórios.', state.subjects.isEmpty ? null : () => showMaterialEditor(context, state));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final m = items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: CircleAvatar(backgroundColor: AppColors.gold.withValues(alpha: .12), child: Icon(_icon(m.kind), color: AppColors.gold)),
            title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            subtitle: Text('${materialKindLabel(m.kind)} • ${state.subjectName(m.subjectId)}${m.description.isEmpty ? '' : '\n${m.description}'}', maxLines: 3, overflow: TextOverflow.ellipsis),
            onTap: () => showMaterialEditor(context, state, material: m),
            trailing: PopupMenuButton<String>(
              onSelected: (v) async {
                if (v == 'edit') await showMaterialEditor(context, state, material: m);
                if (v == 'delete' && await confirmDelete(context, m.title)) await state.deleteMaterial(m);
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Excluir'))],
            ),
          ),
        );
      },
    );
  }

  Widget _empty(IconData icon, String title, String message, VoidCallback? action) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 50),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), FilledButton.icon(onPressed: action, icon: const Icon(Icons.add_rounded), label: const Text('Adicionar'))],
          ]),
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
