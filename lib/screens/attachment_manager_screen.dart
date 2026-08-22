import 'dart:io';

import 'package:flutter/material.dart';

import '../models/attachment.dart';
import '../services/attachment_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

Future<void> showAttachmentManager(
  BuildContext context, {
  required AttachmentTarget target,
  required String title,
}) async {
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => AttachmentManagerScreen(target: target, title: title),
    ),
  );
}

class AttachmentManagerScreen extends StatefulWidget {
  const AttachmentManagerScreen({
    super.key,
    required this.target,
    required this.title,
  });

  final AttachmentTarget target;
  final String title;

  @override
  State<AttachmentManagerScreen> createState() => _AttachmentManagerScreenState();
}

class _AttachmentManagerScreenState extends State<AttachmentManagerScreen> {
  final repository = AttachmentRepository.instance;
  List<AcademicAttachment> items = const [];
  bool loading = true;
  bool importing = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final result = await repository.forTarget(widget.target);
      if (!mounted) return;
      setState(() {
        items = result;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Não foi possível carregar os anexos: $e';
      });
    }
  }

  Future<void> _add(String action) async {
    if (importing) return;
    setState(() => importing = true);
    try {
      if (action == 'camera') {
        await repository.takePhoto(target: widget.target);
      } else if (action == 'gallery') {
        await repository.pickImages(target: widget.target);
      } else {
        await repository.pickFiles(target: widget.target);
      }
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível adicionar o anexo. $e')),
      );
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anexos'),
        actions: [
          _AddAttachmentButton(onSelected: _add, enabled: !importing),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                child: PageHeader(
                  title: widget.title,
                  subtitle: '${attachmentTargetLabel(widget.target.type)} • arquivos guardados dentro do Academia Flow',
                ),
              ),
              if (importing) const LinearProgressIndicator(minHeight: 3),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
      floatingActionButton: PopupMenuButton<String>(
        enabled: !importing,
        onSelected: _add,
        itemBuilder: (_) => _addItems(),
        child: FloatingActionButton.extended(
          heroTag: 'attachment-add',
          onPressed: null,
          icon: importing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_rounded),
          label: Text(importing ? 'Adicionando…' : 'Adicionar'),
        ),
      ),
    );
  }

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 12),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              FilledButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh_rounded), label: const Text('Tentar novamente')),
            ],
          ),
        ),
      );
    }
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.attach_file_rounded,
        title: 'Nenhum anexo',
        message: 'Adicione fotos, PDFs, documentos ou outros arquivos relacionados a este item.',
        actionLabel: 'Adicionar arquivo',
        onAction: () => _add('file'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) => _AttachmentCard(
        item: items[index],
        onOpen: () => _open(items[index]),
        onRename: () => _rename(items[index]),
        onDelete: () => _delete(items[index]),
      ),
    );
  }

  Future<void> _open(AcademicAttachment item) async {
    try {
      if (item.kind == AttachmentKind.image) {
        final file = await repository.resolveFile(item);
        if (!await file.exists()) throw StateError('Arquivo não encontrado.');
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              children: [
                Container(
                  constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 850),
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: .5,
                    maxScale: 5,
                    child: Center(child: Image.file(file, fit: BoxFit.contain)),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton.filled(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        await repository.openExternally(item);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível abrir o arquivo. $e')));
    }
  }

  Future<void> _rename(AcademicAttachment item) async {
    final controller = TextEditingController(text: item.title);
    try {
      final value = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Renomear anexo'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Nome'),
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Salvar')),
          ],
        ),
      );
      if (value == null || value.trim().isEmpty) return;
      await repository.rename(item, value);
      await _reload();
    } finally {
      controller.dispose();
    }
  }

  Future<void> _delete(AcademicAttachment item) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Excluir anexo?'),
            content: Text('“${item.title}” será removido do Academia Flow e o arquivo interno será apagado.'),
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
    await repository.delete(item);
    await _reload();
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.item,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final AcademicAttachment item;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(_kindIcon(item.kind), color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  '${attachmentKindLabel(item.kind)} • ${_formatBytes(item.sizeBytes)} • ${_formatDate(item.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'open') onOpen();
              if (value == 'rename') onRename();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'open', child: Text('Abrir')),
              PopupMenuItem(value: 'rename', child: Text('Renomear')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'delete', child: Text('Excluir')),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddAttachmentButton extends StatelessWidget {
  const _AddAttachmentButton({required this.onSelected, required this.enabled});

  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
        enabled: enabled,
        tooltip: 'Adicionar anexo',
        onSelected: onSelected,
        icon: const Icon(Icons.add_rounded),
        itemBuilder: (_) => _addItems(),
      );
}

List<PopupMenuEntry<String>> _addItems() => [
      if (Platform.isAndroid || Platform.isIOS)
        const PopupMenuItem(
          value: 'camera',
          child: ListTile(leading: Icon(Icons.photo_camera_outlined), title: Text('Tirar foto'), contentPadding: EdgeInsets.zero),
        ),
      const PopupMenuItem(
        value: 'gallery',
        child: ListTile(leading: Icon(Icons.photo_library_outlined), title: Text('Escolher imagens'), contentPadding: EdgeInsets.zero),
      ),
      const PopupMenuItem(
        value: 'file',
        child: ListTile(leading: Icon(Icons.attach_file_rounded), title: Text('Selecionar arquivo'), contentPadding: EdgeInsets.zero),
      ),
    ];

IconData _kindIcon(AttachmentKind kind) => switch (kind) {
      AttachmentKind.image => Icons.image_outlined,
      AttachmentKind.pdf => Icons.picture_as_pdf_outlined,
      AttachmentKind.document => Icons.description_outlined,
      AttachmentKind.archive => Icons.folder_zip_outlined,
      AttachmentKind.other => Icons.insert_drive_file_outlined,
    };

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}

String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
