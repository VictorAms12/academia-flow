import 'package:flutter/material.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/forms.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final risk = state.subjects.where(state.isSubjectAtRisk).toList();
    final overall = state.overallAverage;
    final attendance = state.averageAttendance;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageHeader(title: 'Desempenho', subtitle: 'Médias, frequência e indicadores calculados com seus dados reais.'),
              const SizedBox(height: 18),
              if (state.subjects.isEmpty)
                EmptyState(
                  icon: Icons.analytics_outlined,
                  title: 'Ainda não há dados para analisar',
                  message: 'Cadastre suas matérias e notas. Os indicadores aparecerão automaticamente conforme você usar o app.',
                  actionLabel: 'Cadastrar matéria',
                  onAction: () => showSubjectEditor(context, state),
                )
              else ...[
                LayoutBuilder(
                  builder: (context, c) {
                    final cards = [
                      _Kpi(label: 'Média geral', value: overall?.toStringAsFixed(2) ?? '—', caption: overall == null ? 'Sem notas ainda' : 'Limite: ${state.minGrade.toStringAsFixed(1)}', icon: Icons.workspace_premium_rounded, color: AppColors.gold),
                      _Kpi(label: 'Frequência média', value: attendance == null ? '—' : '${attendance.toStringAsFixed(1)}%', caption: 'Mínimo: ${state.minAttendance.toStringAsFixed(0)}%', icon: Icons.fact_check_outlined, color: AppColors.success),
                      _Kpi(label: 'Matérias em risco', value: '${risk.length}', caption: risk.isEmpty ? 'Nenhum alerta atual' : 'Requer atenção', icon: Icons.warning_amber_rounded, color: risk.isEmpty ? AppColors.success : AppColors.danger),
                    ];
                    if (c.maxWidth >= 780) {
                      return Row(children: [
                        for (var i = 0; i < cards.length; i++) ...[
                          Expanded(child: cards[i]),
                          if (i < cards.length - 1) const SizedBox(width: 11),
                        ],
                      ]);
                    }
                    return Column(children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        cards[i],
                        if (i < cards.length - 1) const SizedBox(height: 9),
                      ],
                    ]);
                  },
                ),
                const SizedBox(height: 15),
                LayoutBuilder(
                  builder: (context, c) {
                    final performance = _SubjectPerformance(state: state);
                    final history = _GradeHistory(state: state);
                    if (c.maxWidth >= 850) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: performance),
                          const SizedBox(width: 13),
                          Expanded(flex: 2, child: history),
                        ],
                      );
                    }
                    return Column(children: [performance, const SizedBox(height: 13), history]);
                  },
                ),
                const SizedBox(height: 13),
                _RiskPanel(state: state, risk: risk),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.caption, required this.icon, required this.color});
  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Row(
        children: [
          CircleAvatar(radius: 22, backgroundColor: color.withValues(alpha: .11), child: Icon(icon, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                Text(caption, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectPerformance extends StatelessWidget {
  const _SubjectPerformance({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Desempenho por matéria'),
          const SizedBox(height: 16),
          for (final subject in state.subjects) ...[
            Builder(
              builder: (context) {
                final avg = state.averageForSubject(subject.id!);
                final risk = avg != null && avg < state.minGrade;
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(subject.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                        const SizedBox(width: 8),
                        Text(avg == null ? '—' : avg.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.w900, color: risk ? AppColors.danger : null)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: avg == null ? 0 : (avg / 10).clamp(0.0, 1.0).toDouble(),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(20),
                      color: risk ? AppColors.danger : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 13),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _GradeHistory extends StatelessWidget {
  const _GradeHistory({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final items = [...state.grades]..sort((a, b) => b.date.compareTo(a.date));
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Notas recentes'),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 25),
              child: Center(child: Text('Nenhuma nota cadastrada.', style: Theme.of(context).textTheme.bodySmall)),
            )
          else
            for (final grade in items.take(6)) ...[
              Row(
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: .10), borderRadius: BorderRadius.circular(12)),
                    child: Text(grade.value.toStringAsFixed(1), style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(grade.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(state.subjectName(grade.subjectId), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 18),
            ],
        ],
      ),
    );
  }
}

class _RiskPanel extends StatelessWidget {
  const _RiskPanel({required this.state, required this.risk});
  final AppState state;
  final List<Subject> risk;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(risk.isEmpty ? Icons.verified_outlined : Icons.health_and_safety_outlined, color: risk.isEmpty ? AppColors.success : AppColors.danger),
              const SizedBox(width: 8),
              Text(risk.isEmpty ? 'Situação acadêmica saudável' : 'Indicador de risco', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            risk.isEmpty
                ? 'Nenhuma matéria está abaixo dos limites configurados de nota ou frequência.'
                : 'Confira as disciplinas abaixo. O alerta considera média mínima ${state.minGrade.toStringAsFixed(1)} e frequência mínima ${state.minAttendance.toStringAsFixed(0)}%.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (risk.isNotEmpty) ...[
            const SizedBox(height: 13),
            for (final subject in risk)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: .07), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.danger.withValues(alpha: .14))),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 19),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        '${subject.name}: média ${state.averageForSubject(subject.id!)?.toStringAsFixed(1) ?? '—'} • frequência ${subject.attendance.toStringAsFixed(0)}%',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
