import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int selectedDay = DateTime.now().weekday.clamp(1, 7).toInt();

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final dayEntries = state.schedules.where((e) => e.day == selectedDay).toList()
      ..sort((a, b) => a.start.compareTo(b.start));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Horários & Rotina',
                subtitle: 'Monte sua grade semanal e consulte a agenda de cada dia.',
                action: FilledButton.icon(
                  onPressed: state.subjects.isEmpty ? null : () => showScheduleEditor(context, state),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Adicionar'),
                ),
              ),
              const SizedBox(height: 17),
              if (state.subjects.isEmpty)
                EmptyState(
                  icon: Icons.calendar_month_outlined,
                  title: 'Cadastre uma matéria primeiro',
                  message: 'Os horários são vinculados às matérias. Cadastre pelo menos uma disciplina para montar sua grade.',
                  actionLabel: 'Cadastrar matéria',
                  onAction: () => showSubjectEditor(context, state),
                )
              else if (state.schedules.isEmpty)
                EmptyState(
                  icon: Icons.schedule_rounded,
                  title: 'Sua grade ainda está vazia',
                  message: 'Adicione os horários de aula para consultar sua rotina semanal rapidamente.',
                  actionLabel: 'Adicionar primeiro horário',
                  onAction: () => showScheduleEditor(context, state),
                )
              else ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('Seg')),
                      ButtonSegment(value: 2, label: Text('Ter')),
                      ButtonSegment(value: 3, label: Text('Qua')),
                      ButtonSegment(value: 4, label: Text('Qui')),
                      ButtonSegment(value: 5, label: Text('Sex')),
                      ButtonSegment(value: 6, label: Text('Sáb')),
                      ButtonSegment(value: 7, label: Text('Dom')),
                    ],
                    selected: {selectedDay},
                    onSelectionChanged: (v) => setState(() => selectedDay = v.first),
                    showSelectedIcon: false,
                  ),
                ),
                const SizedBox(height: 15),
                LayoutBuilder(
                  builder: (context, c) {
                    final agenda = _DayAgenda(state: state, day: selectedDay, entries: dayEntries);
                    final overview = _WeekOverview(state: state);
                    if (c.maxWidth >= 860) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: agenda),
                          const SizedBox(width: 13),
                          Expanded(flex: 3, child: overview),
                        ],
                      );
                    }
                    return Column(children: [agenda, const SizedBox(height: 13), overview]);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DayAgenda extends StatelessWidget {
  const _DayAgenda({required this.state, required this.day, required this.entries});
  final AppState state;
  final int day;
  final List<ScheduleEntry> entries;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(dayName(day)),
          const SizedBox(height: 13),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 25),
              child: Center(child: Text('Sem aulas cadastradas neste dia.', style: Theme.of(context).textTheme.bodySmall)),
            )
          else
            for (var i = 0; i < entries.length; i++) ...[
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: .065),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: .10)),
                ),
                child: Row(
                  children: [
                    Container(width: 4, height: 51, decoration: BoxDecoration(color: i == 0 ? AppColors.gold : Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(5))),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.subjectName(entries[i].subjectId), style: const TextStyle(fontWeight: FontWeight.w900)),
                          const SizedBox(height: 3),
                          Text('${entries[i].start}–${entries[i].end}${entries[i].room.isEmpty ? '' : ' • ${entries[i].room}'}', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') await showScheduleEditor(context, state, entry: entries[i]);
                        if (value == 'delete' && await confirmDelete(context, 'horário de ${state.subjectName(entries[i].subjectId)}')) await state.deleteSchedule(entries[i]);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Excluir')),
                      ],
                    ),
                  ],
                ),
              ),
              if (i < entries.length - 1) const SizedBox(height: 9),
            ],
        ],
      ),
    );
  }
}

class _WeekOverview extends StatelessWidget {
  const _WeekOverview({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Visão semanal'),
          const SizedBox(height: 13),
          for (var day = 1; day <= 7; day++)
            Builder(
              builder: (context) {
                final entries = state.schedules.where((e) => e.day == day).toList()..sort((a, b) => a.start.compareTo(b.start));
                if (entries.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 74, child: Text(dayName(day).substring(0, 3).toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900))),
                      Expanded(
                        child: Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (final entry in entries)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('${entry.start} ${state.subjectName(entry.subjectId)}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
