import 'package:flutter/material.dart';

import '../integrations/google/google_integration_controller.dart';
import '../models/backup_models.dart';
import '../services/backup_service.dart';
import '../services/maintenance_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final service = BackupService.instance;
  late Future<List<BackupPreview>> backupsFuture;
  bool busy = false;
  bool automatic = false;
  int intervalDays = 7;
  bool settingsLoaded = false;

  @override
  void initState() {
    super.initState();
    backupsFuture = service.internalBackups();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await service.automaticBackupEnabled;
    final interval = await service.automaticBackupIntervalDays;
    if (!mounted) return;
    setState(() {
      automatic = enabled;
      intervalDays = interval;
      settingsLoaded = true;
    });
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => backupsFuture = service.internalBackups());
    await backupsFuture;
  }

  Future<void> _run(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dados e Backup')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const PageHeader(
                      title: 'Proteja sua vida acadêmica',
                      subtitle: 'Backups incluem dados acadêmicos, planejamento, preferências e anexos locais.',
                    ),
                    const SizedBox(height: 16),
                    _statusCard(),
                    const SizedBox(height: 13),
                    _actionsCard(),
                    const SizedBox(height: 13),
                    _automaticCard(),
                    const SizedBox(height: 13),
                    _internalBackupsCard(),
                    const SizedBox(height: 13),
                    _securityCard(),
                  ],
                ),
              ),
            ),
          ),
          if (busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .16),
                child: const Center(
                  child: Card(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                          SizedBox(width: 14),
                          Text('Processando dados…', style: TextStyle(fontWeight: FontWeight.w800)),
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

  Widget _statusCard() {
    return FutureBuilder<List<BackupPreview>>(
      future: backupsFuture,
      builder: (context, snapshot) {
        final backups = snapshot.data ?? const <BackupPreview>[];
        final latest = backups.isEmpty ? null : backups.first;
        return SoftCard(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 610;
              final info = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.shield_outlined, color: AppColors.success),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Proteção local', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                            const SizedBox(height: 3),
                            Text(
                              latest == null
                                  ? 'Nenhum backup interno criado ainda.'
                                  : 'Último backup: ${_dateTime(latest.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (latest != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${latest.subjects} matérias • ${latest.tasks} atividades • ${latest.attachments} anexos • ${_bytes(latest.archiveBytes)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              );
              final badge = Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${backups.length} backup${backups.length == 1 ? '' : 's'} interno${backups.length == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              );
              if (compact) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 12), Align(alignment: Alignment.centerLeft, child: badge)]);
              }
              return Row(children: [Expanded(child: info), const SizedBox(width: 18), badge]);
            },
          ),
        );
      },
    );
  }

  Widget _actionsCard() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Ações'),
          const SizedBox(height: 7),
          Text(
            'Crie uma cópia interna rápida ou exporte um arquivo .afbackup para manter fora do aplicativo.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              FilledButton.icon(
                onPressed: busy ? null : () => _run(_createInternal),
                icon: const Icon(Icons.backup_outlined),
                label: const Text('Criar backup'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _run(_createAndExport),
                icon: const Icon(Icons.save_alt_rounded),
                label: const Text('Criar e exportar'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _run(_restoreExternal),
                icon: const Icon(Icons.settings_backup_restore_rounded),
                label: const Text('Restaurar arquivo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _automaticCard() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: automatic,
            onChanged: !settingsLoaded || busy
                ? null
                : (value) async {
                    setState(() => automatic = value);
                    await service.setAutomaticBackup(enabled: value, intervalDays: intervalDays);
                  },
            secondary: const Icon(Icons.history_rounded),
            title: const Text('Backup automático', style: TextStyle(fontWeight: FontWeight.w900)),
            subtitle: const Text('Cria cópias internas periodicamente quando houver dados acadêmicos.'),
          ),
          if (automatic) ...[
            const Divider(),
            Row(
              children: [
                const Expanded(child: Text('Intervalo entre backups')),
                DropdownButton<int>(
                  value: intervalDays,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Diário')),
                    DropdownMenuItem(value: 3, child: Text('3 dias')),
                    DropdownMenuItem(value: 7, child: Text('Semanal')),
                    DropdownMenuItem(value: 14, child: Text('14 dias')),
                    DropdownMenuItem(value: 30, child: Text('Mensal')),
                  ],
                  onChanged: busy
                      ? null
                      : (value) async {
                          if (value == null) return;
                          setState(() => intervalDays = value);
                          await service.setAutomaticBackup(enabled: automatic, intervalDays: value);
                        },
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text('O app mantém até 5 backups automáticos, 3 manuais internos e 3 backups de segurança.', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  Widget _internalBackupsCard() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: SectionTitle('Backups internos')),
              IconButton(tooltip: 'Atualizar', onPressed: busy ? null : _refresh, icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          const SizedBox(height: 7),
          FutureBuilder<List<BackupPreview>>(
            future: backupsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 22),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final backups = snapshot.data ?? const <BackupPreview>[];
              if (backups.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nenhuma cópia interna disponível.', style: Theme.of(context).textTheme.bodySmall),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < backups.length; i++) ...[
                    _BackupTile(
                      backup: backups[i],
                      onRestore: () => _run(() => _restorePreview(backups[i])),
                      onExport: () => _run(() => _exportExisting(backups[i])),
                      onDelete: () => _deleteBackup(backups[i]),
                    ),
                    if (i < backups.length - 1) const Divider(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _securityCard() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AppColors.gold),
              SizedBox(width: 8),
              Text('Integridade e segurança', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            'Antes de restaurar, o Academia Flow verifica o manifesto, o SHA-256 dos dados e o SHA-256 de cada anexo. Uma cópia de segurança do estado atual é criada automaticamente antes da substituição.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 8),
          Text(
            'Credenciais e tokens Google não são incluídos. Depois de restaurar em outro aparelho, conecte o Google Classroom novamente. O arquivo .afbackup não é criptografado; guarde-o em local confiável.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }

  Future<void> _createInternal() async {
    final file = await service.createInternalBackup();
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup criado: ${file.path.split(RegExp(r'[/\\]')).last}')));
  }

  Future<void> _createAndExport() async {
    final path = await service.createAndExportBackup();
    await _refresh();
    if (!mounted || path == null) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backup exportado com sucesso.')));
  }

  Future<void> _exportExisting(BackupPreview backup) async {
    final result = await service.exportBackupFile(backup.sourcePath);
    if (!mounted || result == null) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cópia exportada com sucesso.')));
  }

  Future<void> _restoreExternal() async {
    final path = await service.pickBackupFile();
    if (path == null) return;
    final preview = await service.inspect(path);
    await _restorePreview(preview);
  }

  Future<void> _restorePreview(BackupPreview preview) async {
    final state = AppStateScope.of(context);
    final confirmed = await _confirmRestore(preview);
    if (!confirmed) return;

    await service.restore(preview.sourcePath);
    await GoogleIntegrationController.instance.clearLocalIntegration();
    await MaintenanceService.instance.reloadFromStorage(state);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 38),
        title: const Text('Backup restaurado'),
        content: const Text('Os dados foram restaurados e as notificações foram reorganizadas. A integração Google deve ser conectada novamente.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Continuar')),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<bool> _confirmRestore(BackupPreview preview) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Restaurar este backup?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dateTime(preview.createdAt), style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('${preview.subjects} matérias • ${preview.tasks} atividades • ${preview.sessions} aulas'),
                Text('${preview.notes} anotações • ${preview.materials} materiais • ${preview.attachments} anexos'),
                const SizedBox(height: 10),
                Text('Versão de origem: ${preview.appVersion} • ${_bytes(preview.archiveBytes)}'),
                const SizedBox(height: 14),
                const Text('O estado atual será salvo automaticamente em um backup de segurança antes da restauração.'),
                const SizedBox(height: 8),
                const Text('A conexão Google não é restaurada e precisará ser conectada novamente.'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, true),
                icon: const Icon(Icons.settings_backup_restore_rounded),
                label: const Text('Restaurar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _deleteBackup(BackupPreview backup) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Excluir backup interno?'),
            content: Text('A cópia de ${_dateTime(backup.createdAt)} será apagada do armazenamento interno do Academia Flow.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _run(() async {
      await service.deleteInternalBackup(backup);
      await _refresh();
    });
  }
}

class _BackupTile extends StatelessWidget {
  const _BackupTile({
    required this.backup,
    required this.onRestore,
    required this.onExport,
    required this.onDelete,
  });

  final BackupPreview backup;
  final VoidCallback onRestore;
  final VoidCallback onExport;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final icon = switch (backup.kind) {
      BackupKind.manual => Icons.inventory_2_outlined,
      BackupKind.automatic => Icons.history_rounded,
      BackupKind.safety => Icons.health_and_safety_outlined,
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(icon)),
      title: Text('${backupKindLabel(backup.kind)} • ${_dateTime(backup.createdAt)}', style: const TextStyle(fontWeight: FontWeight.w900)),
      subtitle: Text('${backup.subjects} matérias • ${backup.tasks} atividades • ${backup.attachments} anexos • ${_bytes(backup.archiveBytes)}'),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'restore') onRestore();
          if (value == 'export') onExport();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'restore', child: Text('Restaurar')),
          PopupMenuItem(value: 'export', child: Text('Exportar cópia')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'delete', child: Text('Excluir')),
        ],
      ),
    );
  }
}

String _dateTime(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(value.day)}/${two(value.month)}/${value.year} • ${two(value.hour)}:${two(value.minute)}';
}

String _bytes(int value) {
  if (value < 1024) return '$value B';
  if (value < 1024 * 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
  if (value < 1024 * 1024 * 1024) return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

String _friendlyError(Object error) {
  final text = '$error'.replaceFirst('Bad state: ', '').replaceFirst('StateError: ', '').replaceFirst('FormatException: ', '');
  if (text.contains('No space left') || text.contains('ENOSPC')) return 'Não há espaço livre suficiente para concluir o backup.';
  if (text.contains('Permission denied')) return 'O sistema não permitiu acessar esse local. Escolha outra pasta ou arquivo.';
  return text;
}
