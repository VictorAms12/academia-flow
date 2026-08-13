import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController name;
  late TextEditingController course;
  late TextEditingController period;
  late TextEditingController semester;
  late TextEditingController minGrade;
  late TextEditingController minAttendance;
  bool _controllersReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllersReady) return;
    final state = AppStateScope.of(context);
    name = TextEditingController(text: state.userName);
    course = TextEditingController(text: state.course);
    period = TextEditingController(text: state.period);
    semester = TextEditingController(text: state.semester);
    minGrade = TextEditingController(text: state.minGrade.toStringAsFixed(1).replaceAll('.', ','));
    minAttendance = TextEditingController(text: state.minAttendance.toStringAsFixed(0));
    _controllersReady = true;
  }

  @override
  void dispose() {
    name.dispose();
    course.dispose();
    period.dispose();
    semester.dispose();
    minGrade.dispose();
    minAttendance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PageHeader(title: 'Seu espaço acadêmico', subtitle: 'Personalize seus dados e critérios de acompanhamento.'),
                const SizedBox(height: 16),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Perfil'),
                      const SizedBox(height: 13),
                      TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
                      const SizedBox(height: 11),
                      TextField(controller: course, decoration: const InputDecoration(labelText: 'Curso')),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: period, decoration: const InputDecoration(labelText: 'Período'))),
                          const SizedBox(width: 10),
                          Expanded(child: TextField(controller: semester, decoration: const InputDecoration(labelText: 'Semestre'))),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () async {
                            if (name.text.trim().isEmpty || course.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nome e curso são obrigatórios.')));
                              return;
                            }
                            await state.saveProfile(name: name.text, courseName: course.text, periodName: period.text, semesterName: semester.text);
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil atualizado.')));
                          },
                          child: const Text('Salvar perfil'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle('Critérios acadêmicos'),
                      const SizedBox(height: 6),
                      Text('Esses valores definem quando o app mostra um alerta de risco.', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 13),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: minGrade,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Média mínima'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: minAttendance,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Frequência mínima (%)'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: () async {
                            final grade = double.tryParse(minGrade.text.replaceAll(',', '.'));
                            final attendance = double.tryParse(minAttendance.text.replaceAll(',', '.'));
                            if (grade == null || grade < 0 || grade > 10 || attendance == null || attendance < 0 || attendance > 100) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confira os valores informados.')));
                              return;
                            }
                            await state.updateThresholds(grade, attendance);
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Critérios atualizados.')));
                          },
                          child: const Text('Salvar critérios'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                SoftCard(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.isDark,
                    onChanged: (_) => state.toggleTheme(),
                    secondary: Icon(state.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
                    title: const Text('Modo escuro', style: TextStyle(fontWeight: FontWeight.w900)),
                    subtitle: const Text('Alterna entre o tema claro e o azul-petróleo escuro.'),
                  ),
                ),
                const SizedBox(height: 13),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.gold),
                          SizedBox(width: 8),
                          Text('Dados locais', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text('As informações do app ficam armazenadas localmente no banco SQLite do aparelho. Limpar os dados do aplicativo ou desinstalá-lo remove esse banco.', style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5)),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                SoftCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Zona de segurança', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w900, fontSize: 17)),
                      const SizedBox(height: 6),
                      Text('Use estas opções apenas quando quiser começar um semestre do zero ou redefinir completamente o aplicativo.', style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _clearAcademic(context, state),
                            icon: const Icon(Icons.cleaning_services_outlined),
                            label: const Text('Apagar dados acadêmicos'),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                            onPressed: () => _resetEverything(context, state),
                            icon: const Icon(Icons.delete_forever_outlined),
                            label: const Text('Redefinir aplicativo'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _clearAcademic(BuildContext context, AppState state) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Apagar dados acadêmicos?'),
            content: const Text('Matérias, atividades, notas, horários e anotações serão apagados. Seu perfil e preferências serão mantidos.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Apagar dados')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    await state.clearAcademicData();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dados acadêmicos apagados.')));
  }

  Future<void> _resetEverything(BuildContext context, AppState state) async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Redefinir aplicativo?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tudo será apagado, inclusive perfil e configurações. Digite APAGAR para confirmar.'),
                const SizedBox(height: 12),
                TextField(controller: controller, decoration: const InputDecoration(hintText: 'APAGAR')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(dialogContext, controller.text.trim().toUpperCase() == 'APAGAR'),
                child: const Text('Redefinir'),
              ),
            ],
          ),
        ) ??
        false;
    controller.dispose();
    if (!ok) return;
    await state.resetEverything();
    if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
