import 'package:flutter/material.dart';

import '../models/models.dart';
import '../models/v26_models.dart';
import '../state/app_state.dart';
import '../state/v26_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/v22_actions.dart';
import '../widgets/v26_actions.dart';
import 'weekly_planner_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final smart = V26Controller.instance;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) return;
    started = true;
    smart.initialize(AppStateScope.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    smart.bind(state);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Central de avisos'),
        actions: [
          TextButton.icon(
            onPressed: smart.dismissedInsights.isEmpty ? null : smart.restoreInsights,
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Restaurar'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedBuilder(
        animation: smart,
        builder: (context, _) {
          if (smart.loading && !smart.initialized) return const Center(child: CircularProgressIndicator());
          final insights = smart.activeInsights(state);
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PageHeader(
                        title: 'O que precisa da sua atenção',
                        subtitle: 'Avisos são gerados a partir da sua rotina, prazos, provas e frequência — sem depender da internet.',
                      ),
                      const SizedBox(height: 15),
                      if (insights.isEmpty)
                        const EmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'Tudo tranquilo por aqui',
                          message: 'Não há prazos críticos, presenças pendentes ou alertas acadêmicos ativos.',
                        )
                      else ...[
                        _Overview(insights: insights),
                        const SizedBox(height: 13),
                        for (final insight in insights) ...[
                          _InsightCard(
                            insight: insight,
                            state: state,
                            smart: smart,
                            onOpen: () => _openInsight(context, state, insight),
                          ),
                          const SizedBox(height: 9),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openInsight(BuildContext context, AppState state, AcademicInsight insight) async {
    if (insight.kind == InsightKind.task || insight.kind == InsightKind.exam) {
      AcademicTask? task;
      for (final item in state.tasks) {
        if (item.id == insight.entityId) {
          task = item;
          break;
        }
      }
      if (task != null) await showTaskEditor(context, state, task: task);
      return;
    }
    if (insight.kind == InsightKind.attendance) {
      final session = state.sessionById(insight.entityId);
      if (session != null) await showAttendanceEditor(context, state, session);
      return;
    }
    if (insight.kind == InsightKind.study) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklyPlannerScreen()));
      return;
    }
    if (insight.kind == InsightKind.performance) {
      state.setIndex(3);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.insights});
  final List<AcademicInsight> insights;

  @override
  Widget build(BuildContext context) {
    final critical = insights.where((item) => item.severity == InsightSeverity.critical).length;
    final attention = insights.where((item) => item.severity == InsightSeverity.attention).length;
    return SoftCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: (critical > 0 ? AppColors.danger : AppColors.gold).withValues(alpha: .11),
            child: Icon(critical > 0 ? Icons.priority_high_rounded : Icons.notifications_active_outlined, color: critical > 0 ? AppColors.danger : AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${insights.length} aviso${insights.length == 1 ? '' : 's'} ativo${insights.length == 1 ? '' : 's'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              Text('$critical crítico${critical == 1 ? '' : 's'} • $attention requer${attention == 1 ? '' : 'em'} atenção', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight, required this.state, required this.smart, required this.onOpen});
  final AcademicInsight insight;
  final AppState state;
  final V26Controller smart;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (insight.kind) {
      InsightKind.task => (Icons.task_alt_outlined, AppColors.warning),
      InsightKind.attendance => (Icons.how_to_reg_rounded, AppColors.gold),
      InsightKind.exam => (Icons.quiz_outlined, AppColors.danger),
      InsightKind.study => (Icons.menu_book_outlined, Theme.of(context).colorScheme.primary),
      InsightKind.routine => (Icons.schedule_rounded, Theme.of(context).colorScheme.primary),
      InsightKind.performance => (Icons.insights_rounded, AppColors.danger),
    };
    final severityColor = switch (insight.severity) {
      InsightSeverity.critical => AppColors.danger,
      InsightSeverity.attention => AppColors.warning,
      InsightSeverity.info => color,
      InsightSeverity.success => AppColors.success,
    };
    return SoftCard(
      onTap: onOpen,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: severityColor.withValues(alpha: .10), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: severityColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 3),
                Text(insight.message, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Dispensar aviso',
            onPressed: () => smart.dismissInsight(insight.id),
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}
