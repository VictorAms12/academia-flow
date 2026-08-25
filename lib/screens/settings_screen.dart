import 'dart:async';

import 'package:flutter/material.dart';

import '../integrations/google/google_integration_controller.dart';
import '../models/backup_models.dart';
import '../services/backup_service.dart';
import '../services/maintenance_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/motion.dart';
import 'backup_screen.dart';
import 'google_integration_screen.dart';

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
  bool ready = false;
  bool googleStarted = false;
  bool savingProfile = false;
  bool savingCriteria = false;
  bool dangerBusy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    if (!googleStarted) {
      googleStarted = true;
      unawaited(GoogleIntegrationController.instance.initialize(state));
    }
    if (ready) return;
    name = TextEditingController(text: state.userName);
    course = TextEditingController(text: state.course);
    period = TextEditingController(text: state.period);
    semester = TextEditingController(text: state.semester);
    minGrade = TextEditingController(text: state.minGrade.toStringAsFixed(1).replaceAll('.', ','));
    minAttendance = TextEditingController(text: state.minAttendance.toStringAsFixed(0));
    ready = true;
  }

  @override
  void dispose() {
    for (final controller in [name, course, period, semester, minGrade, minAttendance]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final google = GoogleIntegrationController.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const PageHeader(
                        title: 'Seu espaço acadêmico',
                        subtitle: 'Perfil, critérios, integrações, aparência e proteção dos seus dados.',
                      ),
                      const SizedBox(height: 16),
                      _profile(state),
                      const SizedBox(height: 13),
                      AnimatedBuilder(
                        animation: google,
                        builder: (_, __) => _NavigationCard(
                          icon: Icons.account_circle_outlined,
                          title: 'Google & Classroom',
                          subtitle: google.account == null
                              ? 'Login opcional, turmas e atividades do Classroom.'
                              : '${google.account!.email} • ${google.account!.classroomConnected ? 'Classroom conectado' : 'Classroom não conectado'}',
                          onTap: () => Navigator.push(context, motionRoute(const GoogleIntegrationScreen())),
                        ),
                      ),
                      const SizedBox(height: 13),
                      _criteria(state),
                      const SizedBox(height: 13),
                      SoftCard(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: state.isDark,
                          onChanged: (_) => state.toggleTheme(),
                          secondary: Icon(state.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
                          title: const Text('Modo escuro', style: TextStyle(fontWeight: FontWeight.w900)),
                          subtitle: const Text('Alterna entre os temas claro e escuro.'),
                        ),
                      ),
                      const SizedBox(height: 13),
                      _NavigationCard(
                        icon: Icons.backup_outlined,
                        iconColor: AppColors.success,
                        title: 'Dados e Backup',
                        subtitle: 'Crie, exporte e restaure dados acadêmicos, planejamento e anexos.',
                        onTap: () => Navigator.push(context, motionRoute(const BackupScreen())),
                      ),
                      const SizedBox(height: 13),
                      SoftCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(Icons.shield_outlined, color: AppColors.gold),
                              SizedBox(width: 8),
                              Text('Dados locais', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                            ]),
                            const SizedBox(height: 7),
                            Text(
                              'O SQLite guarda os dados acadêmicos e os anexos ficam no armazenamento interno do Academia Flow. Credenciais Google não são incluídas nos backups.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 13),
                      _dangerZone(state),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (dangerBusy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .14),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2.5)),
                        SizedBox(width: 13),
                        Text('Protegendo seus dados…', style: TextStyle(fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _profile(AppState state) => SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Perfil'),
          const SizedBox(height: 13),
          TextField(controller: name, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Nome')),
          const SizedBox(height: 11),
          TextField(controller: course, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Curso')),
          const SizedBox(height: 11),
          _responsivePair(
            TextField(controller: period, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Período')),
            TextField(controller: semester, decoration: const InputDecoration(labelText: 'Semestre')),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: savingProfile ? null : () => _saveProfile(state),
              icon: savingProfile ? const _ButtonLoader() : const Icon(Icons.save_outlined),
              label: Text(savingProfile ? 'Salvando…' : 'Salvar perfil'),
            ),
          ),
        ]),
      );

  Widget _criteria(AppState state) => SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SectionTitle('Critérios acadêmicos'),
          const SizedBox(height: 6),
          Text('Definem os alertas de desempenho e frequência.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 13),
          _responsivePair(
            TextField(controller: minGrade, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Média mínima')),
            TextField(controller: minAttendance, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Frequência mínima (%)')),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: savingCriteria ? null : () => _saveCriteria(state),
              icon: savingCriteria ? const _ButtonLoader() : const Icon(Icons.tune_rounded),
              label: Text(savingCriteria ? 'Salvando…' : 'Salvar critérios'),
            ),
          ),
        ]),
      );

  Widget _responsivePair(Widget first, Widget second) => LayoutBuilder(
        builder: (_, constraints) => constraints.maxWidth < 480
            ? Column(children: [first, const SizedBox(height: 11), second])
            : Row(children: [Expanded(child: first), const SizedBox(width: 10), Expanded(child: second)]),
      );

  Widget _dangerZone(AppState state) => SoftCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Zona de segurança', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 6),
          Text('Um backup interno de segurança é criado antes de qualquer exclusão em massa.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          Wrap(spacing: 9, runSpacing: 9, children: [
            OutlinedButton.icon(
              onPressed: dangerBusy ? null : () => _clearAcademic(state),
              icon: const Icon(Icons.cleaning_services_outlined),
              label: const Text('Apagar dados acadêmicos'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
              onPressed: dangerBusy ? null : () => _resetEverything(state),
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('Redefinir aplicativo'),
            ),
          ]),
        ]),
      );

  Future<void> _saveProfile(AppState state) async {
    if (name.text.trim().isEmpty || course.text.trim().isEmpty) return _snack('Nome e curso são obrigatórios.');
    setState(() => savingProfile = true);
    try {
      await state.saveProfile(name: name.text, courseName: course.text, periodName: period.text, semesterName: semester.text);
      _snack('Perfil atualizado.');
    } catch (e) {
      _snack('Não foi possível salvar o perfil: $e');
    } finally {
      if (mounted) setState(() => savingProfile = false);
    }
  }

  Future<void> _saveCriteria(AppState state) async {
    final grade = double.tryParse(minGrade.text.replaceAll(',', '.'));
    final attendance = double.tryParse(minAttendance.text.replaceAll(',', '.'));
    if (grade == null || grade < 0 || grade > 10 || attendance == null || attendance < 0 || attendance > 100) {
      return _snack('Confira os valores informados.');
    }
    setState(() => savingCriteria = true);
    try {
      await state.updateThresholds(grade, attendance);
      _snack('Critérios atualizados.');
    } catch (e) {
      _snack('Não foi possível salvar os critérios: $e');
    } finally {
      if (mounted) setState(() => savingCriteria = false);
    }
  }

  Future<void> _clearAcademic(AppState state) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Apagar dados acadêmicos?'),
            content: const Text('Matérias, atividades, notas, horários, aulas, anotações, materiais, anexos e planejamento serão apagados. Perfil e preferências serão mantidos.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Criar backup e apagar')),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    setState(() => dangerBusy = true);
    try {
      await BackupService.instance.createInternalBackup(kind: BackupKind.safety);
      await state.clearAcademicData();
      await MaintenanceService.instance.afterAcademicClear(state);
      await GoogleIntegrationController.instance.reloadLinks();
      _snack('Dados acadêmicos apagados. Backup de segurança preservado.');
    } catch (e) {
      _snack('Operação cancelada: não foi possível proteger os dados. $e');
    } finally {
      if (mounted) setState(() => dangerBusy = false);
    }
  }

  Future<void> _resetEverything(AppState state) async {
    final text = TextEditingController();
    try {
      final ok = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Redefinir aplicativo?'),
              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tudo será apagado, inclusive perfil, conexão Google e configurações. Um backup será criado primeiro. Digite APAGAR para confirmar.'),
                const SizedBox(height: 12),
                TextField(controller: text, decoration: const InputDecoration(hintText: 'APAGAR')),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                  onPressed: () => Navigator.pop(dialogContext, text.text.trim().toUpperCase() == 'APAGAR'),
                  child: const Text('Criar backup e redefinir'),
                ),
              ],
            ),
          ) ??
          false;
      if (!ok) return;
      setState(() => dangerBusy = true);
      try {
        await BackupService.instance.createInternalBackup(kind: BackupKind.safety);
        await GoogleIntegrationController.instance.clearLocalIntegration();
        await state.resetEverything();
        await MaintenanceService.instance.afterFullReset(state);
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        _snack('Redefinição cancelada: não foi possível proteger os dados. $e');
      } finally {
        if (mounted) setState(() => dangerBusy = false);
      }
    } finally {
      text.dispose();
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }
}

class _NavigationCard extends StatelessWidget {
  const _NavigationCard({required this.icon, required this.title, required this.subtitle, required this.onTap, this.iconColor});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) => SoftCard(
        onTap: onTap,
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (iconColor ?? Theme.of(context).colorScheme.primary).withValues(alpha: .09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            const SizedBox(height: 3),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ])),
          const Icon(Icons.chevron_right_rounded),
        ]),
      );
}

class _ButtonLoader extends StatelessWidget {
  const _ButtonLoader();
  @override
  Widget build(BuildContext context) => const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2));
}
