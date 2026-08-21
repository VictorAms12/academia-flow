import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/v26_actions.dart';

class AttendanceReviewScreen extends StatelessWidget {
  const AttendanceReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final history = [...state.classSessions]..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    final resolved = history.where((session) => session.status != AttendanceStatus.pending).take(30).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Presença')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHeader(
                    title: 'Frequência e revisão',
                    subtitle: 'Compare o impacto de estar presente ou faltar na próxima aula e revise seus registros.',
                  ),
                  const SizedBox(height: 15),
                  if (state.subjects.isEmpty)
                    const EmptyState(
                      icon: Icons.how_to_reg_rounded,
                      title: 'Sem matérias',
                      message: 'Cadastre matérias para acompanhar a frequência.',
                    )
                  else ...[
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth < 760) {
                          return Column(
                            children: [
                              for (var i = 0; i < state.subjects.length; i++) ...[
                                _AttendanceProjectionCard(state: state, subject: state.subjects[i]),
                                if (i < state.subjects.length - 1) const SizedBox(height: 10),
                              ],
                            ],
                          );
                        }

                        final width = (constraints.maxWidth - 10) / 2;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final subject in state.subjects)
                              SizedBox(
                                width: width,
                                child: _AttendanceProjectionCard(state: state, subject: subject),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const SectionTitle('Histórico editável'),
                    const SizedBox(height: 10),
                    if (resolved.isEmpty)
                      const EmptyState(
                        icon: Icons.history_rounded,
                        title: 'Sem registros confirmados',
                        message: 'As presenças e faltas confirmadas aparecerão aqui.',
                      )
                    else
                      SoftCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < resolved.length; i++) ...[
                              _AttendanceHistoryTile(state: state, session: resolved[i]),
                              if (i < resolved.length - 1) const Divider(height: 1),
                            ],
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceProjectionCard extends StatelessWidget {
  const _AttendanceProjectionCard({required this.state, required this.subject});

  final AppState state;
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final target = state.attendanceTarget(subject);
    final remaining = state.remainingAbsences(subject);
    final nextBlock = _nextClassBlock(state, subject);
    final nextClassCount = nextBlock?.classCount ?? 1;
    final presentProjection = _projectAttendance(
      subject,
      additionalClasses: nextClassCount,
      additionalAbsences: 0,
    );
    final absentProjection = _projectAttendance(
      subject,
      additionalClasses: nextClassCount,
      additionalAbsences: nextClassCount,
    );
    final risk = state.attendanceRiskLabel(subject);
    final riskColor = switch (risk) {
      'SEGURO' => AppColors.success,
      'ATENÇÃO' => AppColors.gold,
      'RISCO' => AppColors.warning,
      _ => AppColors.danger,
    };

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  risk,
                  style: TextStyle(color: riskColor, fontWeight: FontWeight.w900, fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '${subject.attendance.toStringAsFixed(1)}%',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28),
          ),
          Text(
            '${subject.absences} falta${subject.absences == 1 ? '' : 's'} • ${subject.totalClasses} aulas contabilizadas',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (subject.attendance / 100).clamp(0, 1),
            minHeight: 7,
            borderRadius: BorderRadius.circular(20),
            color: subject.attendance < target ? AppColors.danger : AppColors.success,
          ),
          const SizedBox(height: 12),
          Text(
            remaining >= 9999
                ? 'Defina o total planejado para calcular o limite de faltas.'
                : 'Ainda pode faltar $remaining aula${remaining == 1 ? '' : 's'} mantendo a meta de ${target.toStringAsFixed(0)}%.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          if (nextBlock != null)
            Text(
              'Próxima aula: ${_date(nextBlock.date)} • ${nextBlock.start}–${nextBlock.end} • $nextClassCount aula${nextClassCount == 1 ? '' : 's'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            )
          else
            Text(
              'Sem próxima aula gerada. A projeção considera 1 aula.',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          const SizedBox(height: 8),
          _ProjectionRow(
            icon: Icons.check_circle_rounded,
            label: 'Se estiver presente',
            value: presentProjection,
            color: AppColors.success,
            target: target,
          ),
          const SizedBox(height: 7),
          _ProjectionRow(
            icon: Icons.cancel_rounded,
            label: 'Se faltar',
            value: absentProjection,
            color: absentProjection < target ? AppColors.danger : AppColors.gold,
            target: target,
          ),
        ],
      ),
    );
  }
}

class _ProjectionRow extends StatelessWidget {
  const _ProjectionRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.target,
  });

  final IconData icon;
  final String label;
  final double value;
  final Color color;
  final double target;

  @override
  Widget build(BuildContext context) {
    final reachesTarget = value >= target;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: .16)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${value.toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.w900, color: color),
              ),
              Text(
                reachesTarget ? 'meta atingida' : 'abaixo da meta',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceHistoryTile extends StatelessWidget {
  const _AttendanceHistoryTile({required this.state, required this.session});

  final AppState state;
  final ClassSession session;

  @override
  Widget build(BuildContext context) {
    final color = switch (session.status) {
      AttendanceStatus.present => AppColors.success,
      AttendanceStatus.absent => AppColors.danger,
      AttendanceStatus.cancelled => Colors.grey,
      AttendanceStatus.pending => AppColors.gold,
    };
    final label = switch (session.status) {
      AttendanceStatus.present => 'Presente',
      AttendanceStatus.absent => 'Falta',
      AttendanceStatus.cancelled => 'Cancelada',
      AttendanceStatus.pending => 'Pendente',
    };

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .10),
        child: Icon(
          session.status == AttendanceStatus.present
              ? Icons.check_rounded
              : session.status == AttendanceStatus.absent
                  ? Icons.close_rounded
                  : Icons.event_busy_rounded,
          color: color,
        ),
      ),
      title: Text(state.subjectName(session.subjectId), style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        '${_date(session.date)} • ${session.start}–${session.end} • ${session.classCount} aula${session.classCount == 1 ? '' : 's'}${session.note.isEmpty ? '' : '\n${session.note}'}',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
          IconButton(
            tooltip: 'Revisar registro',
            onPressed: () => showAttendanceEditor(context, state, session),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
    );
  }
}

ClassSession? _nextClassBlock(AppState state, Subject subject) {
  if (subject.id == null) return null;
  final now = DateTime.now();
  final candidates = state.classSessions
      .where(
        (session) =>
            session.subjectId == subject.id &&
            session.status != AttendanceStatus.cancelled &&
            session.startsAt.isAfter(now),
      )
      .toList()
    ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return candidates.isEmpty ? null : candidates.first;
}

double _projectAttendance(
  Subject subject, {
  required int additionalClasses,
  required int additionalAbsences,
}) {
  final classes = additionalClasses.clamp(0, 9999).toInt();
  final absences = additionalAbsences.clamp(0, classes).toInt();
  final total = subject.totalClasses + classes;
  final misses = subject.absences + absences;
  if (total <= 0) return 100;
  return ((total - misses).clamp(0, total) / total) * 100;
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
