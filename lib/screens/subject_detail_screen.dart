import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SubjectDetailScreen extends StatefulWidget {
  const SubjectDetailScreen({super.key, required this.subject});
  final Subject subject;

  @override
  State<SubjectDetailScreen> createState() => _SubjectDetailScreenState();
}

class _SubjectDetailScreenState extends State<SubjectDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs;
  final checks = [true, true, false, false];

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.subject;
    return Scaffold(
      appBar: AppBar(
        title: Text(s.name, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: SoftCard(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final compact = c.maxWidth < 620;
                      final identity = Row(
                        children: [
                          CircleAvatar(
                            radius: 27,
                            backgroundColor: s.color.withValues(alpha: .14),
                            child: Icon(s.icon, color: s.color),
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.professor, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text('${s.room} • Semestre 2026.2',
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      );
                      final metrics = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _miniMetric('Média', s.grade.toStringAsFixed(1)),
                          const SizedBox(width: 18),
                          _miniMetric('Frequência', '${s.attendance}%'),
                        ],
                      );
                      return compact
                          ? Column(
                              children: [identity, const SizedBox(height: 16), Align(alignment: Alignment.centerLeft, child: metrics)])
                          : Row(children: [Expanded(child: identity), metrics]);
                    },
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: TabBar(
                controller: tabs,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Aulas'),
                  Tab(text: 'Atividades & Provas'),
                  Tab(text: 'Materiais'),
                  Tab(text: 'Detalhes'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1080),
                child: TabBarView(
                  controller: tabs,
                  children: [
                    _AulasTab(subject: s),
                    _ActivitiesTab(subject: s),
                    const _MaterialsTab(),
                    _DetailsTab(checks: checks, onChanged: (i, v) => setState(() => checks[i] = v)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _AulasTab extends StatelessWidget {
  const _AulasTab({required this.subject});
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    final lessons = [
      ('12 AGO', 'Introdução e fundamentos', 'Concluída'),
      ('19 AGO', 'Estruturas e aplicação prática', 'Próxima'),
      ('26 AGO', 'Laboratório guiado', 'Planejada'),
      ('02 SET', 'Revisão e exercícios', 'Planejada'),
    ];
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionTitle('Cronograma de aulas'),
        const SizedBox(height: 12),
        for (var i = 0; i < lessons.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: subject.color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(lessons[i].$1,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lessons[i].$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(lessons[i].$3, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.more_horiz_rounded),
                  )
                ],
              ),
            ),
          )
      ],
    );
  }
}

class _ActivitiesTab extends StatelessWidget {
  const _ActivitiesTab({required this.subject});
  final Subject subject;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionTitle('Atividades e avaliações'),
        const SizedBox(height: 12),
        _activity(context, 'Trabalho prático I', 'Em andamento', '23 AGO', AppColors.gold),
        const SizedBox(height: 10),
        _activity(context, 'Lista de revisão', 'Pendente', '28 AGO', Theme.of(context).colorScheme.primary),
        const SizedBox(height: 10),
        _activity(context, 'Prova bimestral', 'Pendente', '05 SET', AppColors.danger),
        const SizedBox(height: 10),
        _activity(context, 'Exercícios iniciais', 'Entregue', '10 AGO', AppColors.success),
      ],
    );
  }

  Widget _activity(BuildContext context, String title, String status, String date, Color color) {
    return SoftCard(
      child: Row(
        children: [
          Container(width: 4, height: 48, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          GoldBadge(date),
        ],
      ),
    );
  }
}

class _MaterialsTab extends StatelessWidget {
  const _MaterialsTab();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.picture_as_pdf_rounded, 'Slides — Unidade 01', 'PDF • 3,8 MB'),
      (Icons.description_rounded, 'Resumo da aula 02', 'Anotação'),
      (Icons.link_rounded, 'Playlist complementar', 'Link externo'),
      (Icons.folder_zip_rounded, 'Exemplos práticos', 'ZIP • 1,2 MB'),
    ];
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        SectionTitle(
          'Conteúdos & Materiais',
          trailing: FilledButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Upload simulado no protótipo.')),
              );
            },
            icon: const Icon(Icons.upload_rounded, size: 18),
            label: const Text('Adicionar'),
          ),
        ),
        const SizedBox(height: 12),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              child: Row(
                children: [
                  CircleAvatar(child: Icon(item.$1)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$2, style: const TextStyle(fontWeight: FontWeight.w800)),
                        Text(item.$3, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.open_in_new_rounded)),
                ],
              ),
            ),
          )
      ],
    );
  }
}

class _DetailsTab extends StatelessWidget {
  const _DetailsTab({required this.checks, required this.onChanged});
  final List<bool> checks;
  final void Function(int, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    const steps = [
      'Ler orientações e critérios',
      'Definir escopo da solução',
      'Implementar versão inicial',
      'Revisar e enviar no ambiente virtual',
    ];
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const SectionTitle('Detalhes da atividade em foco'),
        const SizedBox(height: 12),
        const SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GoldBadge('TRABALHO PRÁTICO I'),
              SizedBox(height: 12),
              Text('Orientações', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              SizedBox(height: 7),
              Text(
                'Desenvolva a solução proposta aplicando os conceitos vistos nas últimas aulas. '
                'A entrega deve conter documentação curta, código organizado e evidências de funcionamento.',
                style: TextStyle(height: 1.55),
              ),
              SizedBox(height: 16),
              Text('Critérios de avaliação', style: TextStyle(fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text('• Correção técnica: 4,0\n• Organização e legibilidade: 2,0\n• Documentação: 2,0\n• Apresentação: 2,0'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Checklist de execução', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 8),
              for (var i = 0; i < steps.length; i++)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: checks[i],
                  title: Text(steps[i]),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) => onChanged(i, v ?? false),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
