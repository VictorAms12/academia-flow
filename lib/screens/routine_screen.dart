import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';
import '../widgets/motion.dart';
import '../widgets/routine_dialogs.dart';
import '../widgets/routine_today_card.dart';
import '../widgets/session_actions.dart';
import 'class_detail_screen.dart';

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final pages = [
      _TodayTab(state: state),
      _AttendanceTab(state: state),
      _WeekTab(state: state),
      _CalendarTab(state: state),
      _InsightsTab(state: state),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            PageHeader(
              title: 'Rotina Acadêmica',
              subtitle: 'Aulas, presença, calendário, frequência e hábitos em um só fluxo.',
              action: Wrap(spacing: 8, children: [
                IconButton.filledTonal(tooltip: 'Automação', onPressed: () => showRoutineSettings(context, state), icon: const Icon(Icons.tune_rounded)),
                FilledButton.icon(onPressed: state.subjects.isEmpty ? null : () => showExtraClassEditor(context, state), icon: const Icon(Icons.add_rounded), label: const Text('Aula extra')),
              ]),
            ),
            const SizedBox(height: 15),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, icon: Icon(Icons.today_rounded), label: Text('Hoje')),
                  ButtonSegment(value: 1, icon: Icon(Icons.how_to_reg_rounded), label: Text('Presenças')),
                  ButtonSegment(value: 2, icon: Icon(Icons.view_week_rounded), label: Text('Semana')),
                  ButtonSegment(value: 3, icon: Icon(Icons.event_note_rounded), label: Text('Calendário')),
                  ButtonSegment(value: 4, icon: Icon(Icons.insights_rounded), label: Text('Insights')),
                ],
                selected: {tab},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => tab = v.first),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: MotionSpec.normal,
              switchInCurve: MotionSpec.curve,
              child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final current = state.currentSession;
    return Column(children: [
      RoutineTodayCard(state: state, showHeader: false),
      const SizedBox(height: 14),
      if (current != null)
        SoftCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle('Aula atual'),
            const SizedBox(height: 9),
            Text(state.subjectName(current.subjectId), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            Text('${current.start}–${current.end}${current.room.isEmpty ? '' : ' • ${current.room}'}', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton.icon(onPressed: () => state.markAttendance(current, AttendanceStatus.present), icon: const Icon(Icons.check_rounded), label: const Text('Estou presente')),
              FilledButton.tonalIcon(onPressed: current.id == null ? null : () => Navigator.push(context, motionRoute(ClassDetailScreen(sessionId: current.id!))), icon: const Icon(Icons.open_in_new_rounded), label: const Text('Abrir aula')),
            ]),
          ]),
        ),
      if (state.dueToday.isNotEmpty) ...[
        const SizedBox(height: 14),
        SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Entregas de hoje'),
          const SizedBox(height: 8),
          for (final task in state.dueToday) ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.assignment_rounded), title: Text(task.title), subtitle: Text(state.subjectName(task.subjectId))),
        ])),
      ],
    ]);
  }
}

class _AttendanceTab extends StatelessWidget {
  const _AttendanceTab({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    if (state.subjects.isEmpty) return const EmptyState(icon: Icons.how_to_reg_rounded, title: 'Sem matérias', message: 'Cadastre matérias para acompanhar frequência.');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (state.pendingAttendance.isNotEmpty) ...[
        SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Presenças pendentes'),
          const SizedBox(height: 8),
          for (final session in state.pendingAttendance.take(8))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(state.subjectName(session.subjectId), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text('${formatRoutineDate(session.date)} • ${session.start}–${session.end}'),
              trailing: Wrap(spacing: 4, children: [
                IconButton.filledTonal(onPressed: () => state.markAttendance(session, AttendanceStatus.present), icon: const Icon(Icons.check_rounded)),
                IconButton.filledTonal(onPressed: () => state.markAttendance(session, AttendanceStatus.absent), icon: const Icon(Icons.close_rounded)),
              ]),
            ),
        ])),
        const SizedBox(height: 14),
      ],
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 900 ? 3 : c.maxWidth >= 590 ? 2 : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: state.subjects.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: cols == 1 ? 1.7 : 1.22),
          itemBuilder: (_, i) => _AttendanceCard(state: state, subject: state.subjects[i]),
        );
      }),
      const SizedBox(height: 16),
      _AttendanceHistory(state: state),
    ]);
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.state, required this.subject});
  final AppState state;
  final Subject subject;
  @override
  Widget build(BuildContext context) {
    final attendance = state.attendanceForSubject(subject);
    final target = state.attendanceTarget(subject);
    final remaining = state.remainingAbsences(subject);
    final risk = state.attendanceRiskLabel(subject);
    final riskColor = switch (risk) { 'SEGURO' => AppColors.success, 'ATENÇÃO' => AppColors.gold, 'RISCO' => Colors.orange, _ => AppColors.danger };
    return SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(subject.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: riskColor.withValues(alpha: .11), borderRadius: BorderRadius.circular(20)), child: Text(risk, style: TextStyle(color: riskColor, fontSize: 9, fontWeight: FontWeight.w900)))]),
      const SizedBox(height: 12),
      Text('${attendance.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      Text('meta ${target.toStringAsFixed(0)}% • ${state.completedClassCount(subject)} aulas registradas', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 8),
      LinearProgressIndicator(value: (attendance / 100).clamp(0, 1), minHeight: 7, borderRadius: BorderRadius.circular(20)),
      const Spacer(),
      Text(remaining >= 9999 ? 'Defina o total planejado para calcular faltas restantes.' : 'Você ainda pode faltar $remaining aula${remaining == 1 ? '' : 's'}.', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 9),
      Wrap(spacing: 6, runSpacing: 6, children: [
        TextButton.icon(onPressed: () => showAbsenceSimulator(context, state, subject), icon: const Icon(Icons.science_outlined), label: const Text('Simular')),
        TextButton.icon(onPressed: () => showAttendanceTargetEditor(context, state, subject), icon: const Icon(Icons.flag_outlined), label: const Text('Meta')),
      ]),
    ]));
  }
}

class _AttendanceHistory extends StatelessWidget {
  const _AttendanceHistory({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final history = state.classSessions.where((s) => s.status != AttendanceStatus.pending).toList()..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle('Histórico recente'),
      const SizedBox(height: 8),
      if (history.isEmpty) Text('As presenças confirmadas aparecerão aqui.', style: Theme.of(context).textTheme.bodySmall),
      for (final session in history.take(12))
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: session.id == null ? null : () => Navigator.push(context, motionRoute(ClassDetailScreen(sessionId: session.id!))),
          leading: Icon(_attendanceIcon(session.status), color: _attendanceColor(session.status)),
          title: Text(state.subjectName(session.subjectId), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${formatRoutineDate(session.date)} • ${session.classCount} aula${session.classCount == 1 ? '' : 's'}'),
          trailing: Text(_attendanceText(session.status), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ),
    ]));
  }
}

class _WeekTab extends StatelessWidget {
  const _WeekTab({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Grade semanal', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
        FilledButton.tonalIcon(onPressed: state.subjects.isEmpty ? null : () => showScheduleEditor(context, state), icon: const Icon(Icons.add_rounded), label: const Text('Horário')),
      ]),
      const SizedBox(height: 12),
      for (var day = 1; day <= 7; day++) _DayBlock(state: state, day: day),
    ]);
  }
}

class _DayBlock extends StatelessWidget {
  const _DayBlock({required this.state, required this.day});
  final AppState state;
  final int day;
  @override
  Widget build(BuildContext context) {
    final entries = state.schedules.where((e) => e.day == day).toList()..sort((a, b) => a.start.compareTo(b.start));
    if (entries.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(dayName(day)),
        const SizedBox(height: 9),
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => showScheduleRoutineConfig(context, state, entry),
              borderRadius: BorderRadius.circular(13),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .06), borderRadius: BorderRadius.circular(13)),
                child: Row(children: [
                  SizedBox(width: 92, child: Text('${entry.start}–${entry.end}', style: const TextStyle(fontWeight: FontWeight.w900))),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(state.subjectName(entry.subjectId), style: const TextStyle(fontWeight: FontWeight.w900)), Text('${entry.classCount} aula${entry.classCount == 1 ? '' : 's'} • lembrete ${entry.reminderMinutes} min${entry.room.isEmpty ? '' : ' • ${entry.room}'}', style: Theme.of(context).textTheme.bodySmall)])),
                  const Icon(Icons.tune_rounded, size: 19),
                ]),
              ),
            ),
          ),
      ])),
    );
  }
}

class _CalendarTab extends StatelessWidget {
  const _CalendarTab({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final events = [...state.calendarEvents]..sort((a, b) => a.date.compareTo(b.date));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        FilledButton.icon(onPressed: () => showCalendarEventEditor(context, state), icon: const Icon(Icons.event_rounded), label: const Text('Evento / feriado')),
        FilledButton.tonalIcon(onPressed: state.subjects.isEmpty ? null : () => showExtraClassEditor(context, state), icon: const Icon(Icons.add_circle_outline_rounded), label: const Text('Aula extra')),
        FilledButton.tonalIcon(onPressed: state.subjects.isEmpty ? null : () => showExtraClassEditor(context, state, kind: ClassSessionKind.makeup), icon: const Icon(Icons.replay_rounded), label: const Text('Reposição')),
      ]),
      const SizedBox(height: 14),
      SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Calendário acadêmico'),
        const SizedBox(height: 8),
        if (events.isEmpty) Text('Cadastre feriados, recessos, cancelamentos e semanas de avaliação.', style: Theme.of(context).textTheme.bodySmall),
        for (final event in events.take(20))
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(_eventIcon(event.kind)),
            title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${formatRoutineDate(event.date)}${event.subjectId == null ? '' : ' • ${state.subjectName(event.subjectId)}'}${event.blocksClasses ? ' • sem aula' : ''}'),
            trailing: PopupMenuButton<String>(onSelected: (v) async { if (v == 'edit') await showCalendarEventEditor(context, state, event: event); if (v == 'delete') await state.deleteCalendarEvent(event); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Editar')), PopupMenuItem(value: 'delete', child: Text('Excluir'))]),
          ),
      ])),
    ]);
  }
}

class _InsightsTab extends StatelessWidget {
  const _InsightsTab({required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    final week = state.weeklyAttendanceSummary;
    final resolved = state.classSessions.where((s) => s.status == AttendanceStatus.present || s.status == AttendanceStatus.absent).fold<int>(0, (v, s) => v + s.classCount);
    final present = state.classSessions.where((s) => s.status == AttendanceStatus.present).fold<int>(0, (v, s) => v + s.classCount);
    final overall = resolved == 0 ? 100.0 : present / resolved * 100;
    return Column(children: [
      LayoutBuilder(builder: (context, c) {
        final cards = [
          _InsightCard(icon: Icons.calendar_view_week_rounded, title: 'Esta semana', value: '${week['present'] ?? 0}/${week['classes'] ?? 0}', subtitle: '${week['absent'] ?? 0} faltas • ${week['pending'] ?? 0} pendentes'),
          _InsightCard(icon: Icons.how_to_reg_rounded, title: 'Presença geral', value: '${overall.toStringAsFixed(1)}%', subtitle: '$resolved aulas confirmadas'),
          _InsightCard(icon: Icons.task_alt_rounded, title: 'Atividades concluídas', value: '${state.onTimeTaskRate.toStringAsFixed(0)}%', subtitle: '${state.completedCount}/${state.tasks.length} concluídas'),
          if (state.streakEnabled) _InsightCard(icon: Icons.local_fire_department_rounded, title: 'Sequência', value: '${state.attendanceStreak}', subtitle: 'aulas consecutivas presentes'),
        ];
        final cols = c.maxWidth >= 900 ? 4 : c.maxWidth >= 600 ? 2 : 1;
        return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: cards.length, gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: cols, crossAxisSpacing: 11, mainAxisSpacing: 11, childAspectRatio: cols == 1 ? 2.3 : 1.35), itemBuilder: (_, i) => cards[i]);
      }),
      const SizedBox(height: 14),
      SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SectionTitle('Resumo semanal'),
        const SizedBox(height: 8),
        Text('Você teve ${week['classes'] ?? 0} aulas contabilizadas nesta semana: ${week['present'] ?? 0} presenças, ${week['absent'] ?? 0} faltas e ${week['pending'] ?? 0} confirmações pendentes.'),
        const SizedBox(height: 8),
        Text('No app, o resumo é recalculado automaticamente com base nas ocorrências reais de aula.', style: Theme.of(context).textTheme.bodySmall),
      ])),
    ]);
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.icon, required this.title, required this.value, required this.subtitle});
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  @override
  Widget build(BuildContext context) => SoftCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: AppColors.gold), const Spacer(), Text(title, style: Theme.of(context).textTheme.bodySmall), Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900)), Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall)]));
}

IconData _attendanceIcon(AttendanceStatus status) => switch (status) { AttendanceStatus.present => Icons.check_circle_rounded, AttendanceStatus.absent => Icons.cancel_rounded, AttendanceStatus.cancelled => Icons.event_busy_rounded, AttendanceStatus.pending => Icons.help_rounded };
Color _attendanceColor(AttendanceStatus status) => switch (status) { AttendanceStatus.present => AppColors.success, AttendanceStatus.absent => AppColors.danger, AttendanceStatus.cancelled => Colors.grey, AttendanceStatus.pending => AppColors.gold };
String _attendanceText(AttendanceStatus status) => switch (status) { AttendanceStatus.present => 'Presente', AttendanceStatus.absent => 'Falta', AttendanceStatus.cancelled => 'Cancelada', AttendanceStatus.pending => 'Pendente' };
IconData _eventIcon(AcademicEventKind kind) => switch (kind) { AcademicEventKind.holiday => Icons.celebration_rounded, AcademicEventKind.recess => Icons.beach_access_rounded, AcademicEventKind.cancellation => Icons.event_busy_rounded, AcademicEventKind.examWeek => Icons.quiz_rounded, AcademicEventKind.academicEvent => Icons.school_rounded };
