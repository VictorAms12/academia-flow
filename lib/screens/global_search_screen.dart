import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/v22_actions.dart';
import 'subject_detail_screen.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});
  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  String query = '';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final q = query.trim().toLowerCase();
    final subjects = q.isEmpty ? state.subjects.take(5).toList() : state.subjects.where((s) => '${s.name} ${s.professor} ${s.room}'.toLowerCase().contains(q)).toList();
    final tasks = q.isEmpty ? state.tasks.where((t) => t.status.index < 2).take(5).toList() : state.tasks.where((t) => '${t.title} ${t.description} ${state.subjectName(t.subjectId)}'.toLowerCase().contains(q)).toList();
    final notes = q.isEmpty ? state.notes.take(5).toList() : state.notes.where((n) => '${n.title} ${n.content} ${n.tags}'.toLowerCase().contains(q)).toList();
    final materials = q.isEmpty ? state.materials.take(5).toList() : state.materials.where((m) => '${m.title} ${m.description} ${m.url}'.toLowerCase().contains(q)).toList();
    final empty = subjects.isEmpty && tasks.isEmpty && notes.isEmpty && materials.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Busca global')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => query = v),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Matéria, atividade, anotação ou material...'),
          ),
          const SizedBox(height: 18),
          if (subjects.isNotEmpty) ...[
            _heading('Matérias'),
            ...subjects.map((s) => ListTile(
                  leading: const Icon(Icons.auto_stories_outlined),
                  title: Text(s.name),
                  subtitle: Text(s.professor.isEmpty ? 'Matéria' : s.professor),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectDetailScreen(subjectId: s.id!))),
                )),
          ],
          if (tasks.isNotEmpty) ...[
            _heading('Atividades & provas'),
            ...tasks.map((t) => ListTile(
                  leading: Icon(t.kind.name == 'exam' ? Icons.quiz_outlined : Icons.task_alt_outlined),
                  title: Text(t.title),
                  subtitle: Text(state.subjectName(t.subjectId)),
                  trailing: Text('${t.dueDate.day.toString().padLeft(2, '0')}/${t.dueDate.month.toString().padLeft(2, '0')}'),
                  onTap: () => showTaskEditor(context, state, task: t),
                )),
          ],
          if (notes.isNotEmpty) ...[
            _heading('Anotações'),
            ...notes.map((n) => ListTile(
                  leading: Icon(n.pinned ? Icons.push_pin_outlined : Icons.note_alt_outlined),
                  title: Text(n.title),
                  subtitle: Text(state.subjectName(n.subjectId)),
                  onTap: () => showNoteEditor(context, state, note: n),
                )),
          ],
          if (materials.isNotEmpty) ...[
            _heading('Materiais'),
            ...materials.map((m) => ListTile(
                  leading: const Icon(Icons.attach_file_rounded),
                  title: Text(m.title),
                  subtitle: Text(state.subjectName(m.subjectId)),
                  onTap: () => showMaterialEditor(context, state, material: m),
                )),
          ],
          if (empty) const Padding(padding: EdgeInsets.only(top: 70), child: Center(child: Text('Nenhum resultado encontrado.'))),
        ],
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      );
}
