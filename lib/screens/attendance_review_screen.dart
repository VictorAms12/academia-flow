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
    final history = [...state.classSessions]
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    final resolved = history.where((session) => session.status != AttendanceStatus.pending).take(30).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Presença 2.0')),
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
                    subtitle: 'Veja o impacto das próximas faltas e corrija registros sem perder o contexto da aula.',
                  ),
                  const SizedBox(height: 15),
                  if (state.subjects.isEmpty)
                    const EmptyState(icon: Icons.how_to_reg_rounded, title: 'Sem matérias', message: 'Cadastre matérias para acompanhar a frequência.')
                  else ...[
                    LayoutBuilder(
                      builder: (context, c) {
                        final columns = c.maxWidth >= 760 ? 2 : 1;
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: state.subjects.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: columns == 1 ? 2.0 : 1.48,
                          ),
                          itemBuilder: (_, index) => _AttendanceProjectionCard(state: state, subject: state.subjects[index]),
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    const SectionTitle('Histórico editável'),
                    const SizedBox(height: 10),
                    if (resolved.isEmpty)
                      const EmptyState(icon: Icons.history_rounded, title: 'Sem registros confirmados', message: 'As presenças e faltas confirmadas aparecerão aqui.')
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
    final projected = state.simulatedAttendance(subject, 1);
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
              Expanded(child: Text(subject.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: riskColor.withValues(alpha: .10), borderRadius: BorderRadius.circular(20)),
                child: Text(risk, style: TextStyle(color: riskColor, fontWeight: FontWeight.w900, fontSize: 9)),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text('${subject.attendance.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 28)),
          Text('${subject.absences} falta${subject.absences == 1 ? '' : 's'} • ${subject.totalClasses} aulas contabilizadas', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (subject.attendance / 100).clamp(0, 1),
            minHeight: 7,
            borderRadius: BorderRadius.circular(20),
            color: subject.attendance < target ? AppColors.danger : AppColors.success,
          ),
          const Spacer(),
          Text(
            remaining >= 9999
                ? 'Defina o total planejado para calcular o limite de faltas.'
                : 'Ainda pode faltar $remaining aula${remaining == 1 ? '' : 's'} mantendo a meta de ${target.toStringAsFixed(0)}%.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 5),
          Text(
            'Se faltar mais 1 aula → ${projected.toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: FontWeight.w800, color: projected < target ? AppColors.danger : AppColors.gold),
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
        child: Icon(session.status == AttendanceStatus.present ? Icons.check_rounded : session.status == AttendanceStatus.absent ? Icons.close_rounded : Icons.event_busy_rounded, color: color),
      ),
      title: Text(state.subjectName(session.subjectId), style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text('${_date(session.date)} • ${session.start}–${session.end} • ${session.classCount} aula${session.classCount == 1 ? '' : 's'}${session.note.isEmpty ? '' : '\n${session.note}'}', maxLines: 3, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: color)),
          IconButton(tooltip: 'Revisar registro', onPressed: () => showAttendanceEditor(context, state, session), icon: const Icon(Icons.edit_outlined)),
        ],
      ),
    );
  }
}

String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
