import 'package:flutter/material.dart';
import '../models/models.dart';
import '../screens/class_detail_screen.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'attendance_feedback.dart';
import 'common.dart';
import 'motion.dart';
import 'routine_dialogs.dart';

class RoutineTodayCard extends StatelessWidget {
  const RoutineTodayCard({super.key, required this.state, this.showHeader = true});
  final AppState state;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final sessions = state.sessionsToday;
    final current = state.currentSession;
    final next = current ?? state.nextSession;
    final pending = state.pendingAttendance.take(2).toList();

    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (showHeader) ...[
          SectionTitle('Rotina de hoje', trailing: TextButton(onPressed: () => state.setIndex(4), child: const Text('Abrir rotina'))),
          const SizedBox(height: 12),
        ],
        if (next != null) _NextClass(state: state, session: next, current: current?.id == next.id) else Text('Nenhuma aula futura encontrada.', style: Theme.of(context).textTheme.bodySmall),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: .08), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.gold.withValues(alpha: .18))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${state.pendingAttendance.length} presença${state.pendingAttendance.length == 1 ? '' : 's'} pendente${state.pendingAttendance.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              for (final session in pending) _PendingRow(state: state, session: session),
            ]),
          ),
        ],
        if (sessions.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('TIMELINE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.gold)),
          const SizedBox(height: 8),
          for (var i = 0; i < sessions.length; i++) _TimelineRow(state: state, session: sessions[i], last: i == sessions.length - 1),
        ],
      ]),
    );
  }
}

class _NextClass extends StatelessWidget {
  const _NextClass({required this.state, required this.session, required this.current});
  final AppState state;
  final ClassSession session;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final delta = session.startsAt.difference(now);
    final when = current
        ? 'ACONTECENDO AGORA'
        : delta.inDays > 0
            ? 'EM ${delta.inDays}D'
            : delta.inHours > 0
                ? 'EM ${delta.inHours}H ${delta.inMinutes.remainder(60)}MIN'
                : 'EM ${delta.inMinutes.clamp(0, 999)} MIN';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: session.id == null ? null : () => Navigator.push(context, motionRoute(ClassDetailScreen(sessionId: session.id!))),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withValues(alpha: .07), borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: current ? AppColors.gold.withValues(alpha: .15) : Theme.of(context).colorScheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(current ? Icons.play_circle_fill_rounded : Icons.schedule_rounded, color: current ? AppColors.gold : null),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(when, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: current ? AppColors.gold : Theme.of(context).colorScheme.primary)),
                  if (session.status != AttendanceStatus.pending) _CompactAttendanceBadge(session.status),
                ],
              ),
              const SizedBox(height: 3),
              Text(state.subjectName(session.subjectId), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              Text('${formatRoutineDate(session.date)} • ${session.start}–${session.end}${session.room.isEmpty ? '' : ' • ${session.room}'}', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
    );
  }
}

class _CompactAttendanceBadge extends StatelessWidget {
  const _CompactAttendanceBadge(this.status);
  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (status) {
      AttendanceStatus.present => ('PRESENTE', Icons.check_circle_rounded, AppColors.success),
      AttendanceStatus.absent => ('FALTA', Icons.cancel_rounded, AppColors.danger),
      AttendanceStatus.cancelled => ('CANCELADA', Icons.event_busy_rounded, Colors.grey),
      AttendanceStatus.pending => ('PENDENTE', Icons.schedule_rounded, AppColors.gold),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.state, required this.session});
  final AppState state;
  final ClassSession session;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(children: [
          Expanded(child: Text('${state.subjectName(session.subjectId)} • ${formatRoutineDate(session.date)} ${session.start}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
          IconButton.filledTonal(
            tooltip: 'Presente',
            visualDensity: VisualDensity.compact,
            onPressed: () => markAttendanceWithFeedback(context, state, session, AttendanceStatus.present),
            icon: const Icon(Icons.check_rounded, size: 18),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            tooltip: 'Faltei',
            visualDensity: VisualDensity.compact,
            onPressed: () => markAttendanceWithFeedback(context, state, session, AttendanceStatus.absent),
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ]),
      );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.state, required this.session, required this.last});
  final AppState state;
  final ClassSession session;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = !now.isBefore(session.startsAt) && now.isBefore(session.endsAt) && session.status != AttendanceStatus.cancelled;
    final color = active ? AppColors.gold : _statusColor(session.status, context);
    return InkWell(
      onTap: session.id == null ? null : () => Navigator.push(context, motionRoute(ClassDetailScreen(sessionId: session.id!))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 48, child: Text(session.start, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900))),
        SizedBox(width: 24, child: Column(children: [Container(width: 11, height: 11, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), if (!last) Container(width: 2, height: 48, color: Theme.of(context).dividerColor)])),
        Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(state.subjectName(session.subjectId), style: const TextStyle(fontWeight: FontWeight.w900)),
          Text('${session.classCount} aula${session.classCount == 1 ? '' : 's'} • ${_statusLabel(session.status)}', style: Theme.of(context).textTheme.bodySmall),
        ]))),
      ]),
    );
  }
}

Color _statusColor(AttendanceStatus status, BuildContext context) => switch (status) {
      AttendanceStatus.present => AppColors.success,
      AttendanceStatus.absent => AppColors.danger,
      AttendanceStatus.cancelled => Colors.grey,
      AttendanceStatus.pending => Theme.of(context).colorScheme.primary,
    };

String _statusLabel(AttendanceStatus status) => switch (status) {
      AttendanceStatus.present => 'Presente',
      AttendanceStatus.absent => 'Falta',
      AttendanceStatus.cancelled => 'Cancelada',
      AttendanceStatus.pending => 'Pendente',
    };
