import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  int selectedDay = DateTime.now().weekday.clamp(1, 5).toInt();

  @override
  Widget build(BuildContext context) {
    const days = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta'];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Horários & Rotina',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      )),
              const SizedBox(height: 5),
              Text('Sua semana acadêmica organizada por blocos.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SegmentedButton<int>(
                  segments: [
                    for (var i = 0; i < days.length; i++)
                      ButtonSegment(value: i + 1, label: Text(days[i])),
                  ],
                  selected: {selectedDay},
                  onSelectionChanged: (v) => setState(() => selectedDay = v.first),
                  showSelectedIcon: false,
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 860;
                  final today = _TodaySchedule(day: selectedDay);
                  const week = _WeekOverview();
                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: today),
                        const SizedBox(width: 14),
                        const Expanded(flex: 3, child: week),
                      ],
                    );
                  }
                  return Column(children: [today, const SizedBox(height: 14), week]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodaySchedule extends StatelessWidget {
  const _TodaySchedule({required this.day});
  final int day;

  @override
  Widget build(BuildContext context) {
    final items = scheduleEntries.where((e) => e.day == day).toList();
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Agenda do dia'),
          const SizedBox(height: 15),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: Text('Sem aulas programadas.')),
            ),
          for (var i = 0; i < items.length; i++) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: .10)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 54,
                    decoration: BoxDecoration(
                      color: i == 0 ? AppColors.gold : Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(items[i].subject, style: const TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 3),
                        Text('${items[i].room} • ${items[i].start}–${items[i].end}',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (i < items.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Row(
              children: [
                Icon(Icons.lightbulb_outline_rounded, color: AppColors.gold),
                SizedBox(width: 9),
                Expanded(
                  child: Text('Reserve 30 min antes da primeira aula para uma revisão rápida.',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _WeekOverview extends StatelessWidget {
  const _WeekOverview();

  @override
  Widget build(BuildContext context) {
    const days = ['SEG', 'TER', 'QUA', 'QUI', 'SEX'];
    const slots = ['19:00', '20:50'];
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Grade semanal'),
          const SizedBox(height: 15),
          Row(
            children: [
              const SizedBox(width: 58),
              for (final d in days)
                Expanded(
                  child: Center(
                    child: Text(d, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final slot in slots)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                height: 92,
                child: Row(
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(slot, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                    for (var day = 1; day <= 5; day++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: _slot(context, day, slot),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slot(BuildContext context, int day, String start) {
    final match = scheduleEntries.where((e) => e.day == day && e.start == start).toList();
    if (match.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .025),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .25)),
        ),
      );
    }
    final e = match.first;
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: day.isOdd
            ? AppColors.petroleum.withValues(alpha: .12)
            : AppColors.gold.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: day.isOdd
              ? AppColors.petroleum.withValues(alpha: .16)
              : AppColors.gold.withValues(alpha: .16),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(e.subject,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(e.room,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 8)),
        ],
      ),
    );
  }
}
