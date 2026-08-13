import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'subject_detail_screen.dart';

class SubjectsScreen extends StatefulWidget {
  const SubjectsScreen({super.key});

  @override
  State<SubjectsScreen> createState() => _SubjectsScreenState();
}

class _SubjectsScreenState extends State<SubjectsScreen> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = subjects
        .where((s) => s.name.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Matérias',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      )),
              const SizedBox(height: 5),
              Text('Acompanhe aulas, notas, frequência e materiais.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 18),
              TextField(
                onChanged: (v) => setState(() => search = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Buscar disciplina...',
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cols = constraints.maxWidth >= 980 ? 3 : constraints.maxWidth >= 620 ? 2 : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filtered.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                      childAspectRatio: cols == 1 ? 1.85 : 1.15,
                    ),
                    itemBuilder: (_, i) {
                      final subject = filtered[i];
                      final risk = subject.grade < 7 || subject.attendance < 80;
                      return SoftCard(
                        onTap: () => Navigator.of(context).push(
                          PageRouteBuilder(
                            transitionDuration: const Duration(milliseconds: 320),
                            pageBuilder: (_, animation, __) => FadeTransition(
                              opacity: animation,
                              child: SubjectDetailScreen(subject: subject),
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: subject.color.withValues(alpha: .14),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(subject.icon, color: subject.color),
                                ),
                                const Spacer(),
                                if (risk)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger.withValues(alpha: .11),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text('ATENÇÃO',
                                        style: TextStyle(
                                            color: AppColors.danger,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900)),
                                  )
                                else
                                  const GoldBadge('ATIVA'),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(subject.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                            const SizedBox(height: 5),
                            Text(subject.professor, style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 15),
                                const SizedBox(width: 4),
                                Text(subject.room, style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Expanded(child: _stat(context, 'Média', subject.grade.toStringAsFixed(1))),
                                Container(width: 1, height: 34, color: Theme.of(context).dividerColor),
                                Expanded(child: _stat(context, 'Frequência', '${subject.attendance}%')),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
