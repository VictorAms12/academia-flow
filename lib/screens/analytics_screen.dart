import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Desempenho',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      )),
              const SizedBox(height: 5),
              Text('Indicadores acadêmicos e pontos de atenção.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 780;
                  final cards = [
                    const _KpiCard(label: 'CR estimado', value: '8,24', trend: '+0,18', icon: Icons.workspace_premium_rounded),
                    const _KpiCard(label: 'Frequência média', value: '89,8%', trend: '+2,1%', icon: Icons.fact_check_rounded),
                    _KpiCard(label: 'Riscos acadêmicos', value: '${subjects.where((s) => s.grade < 7 || s.attendance < 80).length}', trend: 'requer atenção', icon: Icons.warning_amber_rounded, danger: true),
                  ];
                  if (wide) {
                    return Row(children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        Expanded(child: cards[i]),
                        if (i < cards.length - 1) const SizedBox(width: 12),
                      ]
                    ]);
                  }
                  return Column(children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      cards[i],
                      if (i < cards.length - 1) const SizedBox(height: 10),
                    ]
                  ]);
                },
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, c) {
                  if (c.maxWidth >= 850) {
                    return const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _SubjectBars()),
                        SizedBox(width: 14),
                        Expanded(flex: 2, child: _GradeHistory()),
                      ],
                    );
                  }
                  return const Column(
                    children: [
                      _SubjectBars(),
                      SizedBox(height: 14),
                      _GradeHistory(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              const _RiskPanel(),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.trend,
    required this.icon,
    this.danger = false,
  });
  final String label;
  final String value;
  final String trend;
  final IconData icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.gold;
    return SoftCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: color.withValues(alpha: .11),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 23)),
                Text(trend, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _SubjectBars extends StatelessWidget {
  const _SubjectBars();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Desempenho por matéria'),
          const SizedBox(height: 18),
          for (final s in subjects) ...[
            Row(
              children: [
                Expanded(
                  child: Text(s.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 10),
                Text(s.grade.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 7),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: s.grade / 10),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 9,
                color: s.grade < 7 ? AppColors.danger : s.color,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(height: 15),
          ]
        ],
      ),
    );
  }
}

class _GradeHistory extends StatelessWidget {
  const _GradeHistory();

  @override
  Widget build(BuildContext context) {
    const values = [7.2, 7.9, 8.1, 7.8, 8.5, 8.9];
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Histórico de notas'),
          const SizedBox(height: 20),
          SizedBox(
            height: 210,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < values.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(values[i].toStringAsFixed(1),
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: values[i] / 10),
                            duration: Duration(milliseconds: 550 + i * 90),
                            curve: Curves.easeOutBack,
                            builder: (_, v, __) => Container(
                              height: 145 * v,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.gold,
                                    AppColors.gold.withValues(alpha: .45),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('N${i + 1}', style: const TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskPanel extends StatelessWidget {
  const _RiskPanel();

  @override
  Widget build(BuildContext context) {
    final risk = subjects.where((s) => s.grade < 7 || s.attendance < 80).toList();
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.health_and_safety_outlined, color: AppColors.danger),
              SizedBox(width: 8),
              Text('Indicador de risco', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ],
          ),
          const SizedBox(height: 6),
          Text('Monitora automaticamente nota e frequência abaixo dos limites.',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          for (final s in risk)
            Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.danger.withValues(alpha: .16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${s.name}: média ${s.grade.toStringAsFixed(1)} • frequência ${s.attendance}%',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
