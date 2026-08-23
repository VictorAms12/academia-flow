import 'dart:async';

import 'package:flutter/material.dart';

import '../integrations/google/google_integration_controller.dart';
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
  bool _controllersReady = false;
  bool _googleInitStarted = false;
  bool _savingProfile = false;
  bool _savingCriteria = false;
  bool _dangerBusy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);
    if (!_googleInitStarted) {
      _googleInitStarted = true;
      unawaited(GoogleIntegrationController.instance.initialize(state));
    }
    if (_controllersReady) return;
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
    final google = GoogleIntegrationController.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 30),
            child: Center(
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
                    _profileCard(state),
                    const SizedBox(height: 13),
                    AnimatedBuilder(
                      animation: google,
                      builder: (context, _) => SoftCard(
                        onTap: () => Navigator.push(context, motionRoute(const GoogleIntegrationScreen())),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Text('G', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Google & Classroom', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                                  const SizedBox(height: 3),
                                  Text(
                                    google.account == null
                                        ? 'Login opcional, turmas e atividades do Classroom.'
                                        : '${google.account!.email} • ${google.account!.classroomConnected ? 'Classroom conectado' : 'Classroom não conectado'}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 13),
                    _criteriaCard(state),
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
                    SoftCard(
                      onTap: () => Navigator.push(context, motionRoute(const BackupScreen())),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.backup_outlined, color: AppColors.success),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Dados e Backup', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                                const SizedBox(height: 3),
                                Text(
                                  'Crie, exporte e restaure cópias de matérias, rotina, notas, planejamento e anexos.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
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
                          Text(
                            'Os dados acadêmicos permanecem no SQLite do aparelho e os anexos são copiados para o armazenamento interno do Academia Flow. A conexão Google é opcional e suas credenciais não entram nos backups.',
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
          ),
          if (_dangerBusy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .14),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2.5)),
                          SizedBox(width: 13),
                          Text('Criando backup de segurança…', style: TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _profileCard(AppState state) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Perfil'),
          const SizedBox(height: 13),
          TextField(controller: name, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Nome')),
          const SizedBox(height: 11),
          TextField(controller: course, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Curso')),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 480;
              final fields = [
                TextField(controller: period, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Período')),
                TextField(controller: semester, decoration: const InputDecoration(labelText: 'Semestre')),
              ];
              if (compact) return Column(children: [fields[0], const SizedBox(height: 11), fields[1]]);
              return Row(children: [Expanded(child: fields[0]), const SizedBox(width: 10), Expanded(child: fields[1])]);
            },
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _savingProfile ? null : () => _saveProfile(state),
              icon: _savingProfile
                  ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_savingProfile ? 'Salvando…' : 'Salvar perfil'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _criteriaCard(AppState state) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Critérios acadêmicos'),
          const SizedBox(height: 6),
          Text('Esses valores definem alertas de desempenho e frequência.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 13),
          LayoutBuilder(
            builder: (context, constraints) {
              final grade = TextField(
                controller: minGrade,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Média mínima'),
              );
              final attendance = TextField(
                controller: minAttendance,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Frequência mínima (%)'),
              );
              if (constraints.maxWidth < 480) return Column(children: [grade, const SizedBox(height: 11), attendance]);
              return Row(children: [Expanded(child: grade), const SizedBox(width: 10), Expanded(child: attendance)]);
            },
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _savingCriteria ? null : () => _saveCriteria(state),
              icon: _savingCriteria
                  ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.tune_rounded),
              label: Text(_savingCriteria ? 'Salvando…' : 'Salvar critérios'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dangerZone(AppState state) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Zona de segurança', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w900, fontSize: 17)),
          const SizedBox(height: 6),
          Text(
            'As duas ações abaixo criam um backup interno de segurança antes de apagar qualquer informação.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              OutlinedButton.icon(
                onPressed: _dangerBusy ? null : () => _clearAcademic(context, state),
                icon: const Icon(Icons.cleaning_services_outlined),
                label: const Text('Apagar dados acadêmicos'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: _dangerBusy ? null : () => _resetEverything(context, state),
                icon: const Icon(Icons.delete_forever_outlined),
                label: const Text('Redefinir aplicativo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile(AppState state) async {
    if (name.text.trim().isEmpty || course.text.trim().isEmpty) {
      _snack('Nome e curso são obrigatórios.');
      return;
    }
    setState(() => _savingProfile = true);
    try {
      await state.saveProfile(name: name.text, courseName: course.text, periodName: period.text, semesterName: semester.text);
      if (mounted) _snack('Perfil atualizado.');
    } catch (e) {
      if (mounted) _snack('Não foi possível salvar o perfil: $e');
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _saveCriteria(AppState state) async {
    final grade = double.tryParse(minGrade.text.replaceAll(',', '.'));
    final attendance = double.tryParse(minAttendance.text.replaceAll(',', '.'));
    if (grade == null || grade < 0 || grade > 10 || attendance == null || attendance < 0 || attendance > 100) {
      _snack('Confira os valores informados.');
      return;
    }
    setState(() => _savingCriteria = true);
    try {
      await state.updateThresholds(grade, attendance);
      if (mounted) _snack('Critérios atualizados.');
    } catch (e) {
      if (mounted) _snack('Não foi possível salvar os critérios: $e');
    } finally {
      if (mounted) setState(() => _savingCriteria = false);
    }
  }

  Future<void> _clearAcademic(BuildContext context, AppState state) async {
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

    setState(() => _dangerBusy = true);
    try {
      await BackupService.instance.createInternalBackup(kind: BackupKind.safety);
      await state.clearAcademicData();
      await MaintenanceService.instance.afterAcademicClear(state);
      await GoogleIntegrationController.instance.reloadLinks();
      if (mounted) _snack('Dados acadêmicos apagados. O backup de segurança foi preservado.');
    } catch (e) {
      if (mounted) _snack('Operação cancelada: não foi possível concluir a proteção dos dados. $e');
    } finally {
      if (mounted) setState(() => _dangerBusy = false);
    }
  }

  Future<void> _resetEverything(BuildContext context, AppState state) async {
    final text = TextEditingController();
    try {
      final ok = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Redefinir aplicativo?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tudo será apagado, inclusive perfil, conexão Google e configurações. Um backup de segurança será criado primeiro. Digite APAGAR para confirmar.'),
                  const SizedBox(height: 12),
                  TextField(controller: text, decoration: const InputDecoration(hintText: 'APAGAR')),
                ],
              ),
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

      setState(() => _dangerBusy = true);
      try {
        await BackupService.instance.createInternalBackup(kind: BackupKind.safety);
        await GoogleIntegrationController.instance.clearLocalIntegration();
        await state.resetEverything();
        await MaintenanceService.instance.afterFullReset(state);
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      } catch (e) {
        if (mounted) _snack('Redefinição cancelada: não foi possível concluir o backup de segurança. $e');
      } finally {
        if (mounted) setState(() => _dangerBusy = false);
      }
    } finally {
      text.dispose();
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }
}
