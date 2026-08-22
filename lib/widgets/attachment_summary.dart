import 'package:flutter/material.dart';

import '../models/attachment.dart';
import '../screens/attachment_manager_screen.dart';
import '../services/attachment_repository.dart';
import '../theme/app_theme.dart';
import 'common.dart';

class AttachmentSummaryCard extends StatefulWidget {
  const AttachmentSummaryCard({
    super.key,
    required this.target,
    required this.title,
    this.compact = false,
  });

  final AttachmentTarget target;
  final String title;
  final bool compact;

  @override
  State<AttachmentSummaryCard> createState() => _AttachmentSummaryCardState();
}

class _AttachmentSummaryCardState extends State<AttachmentSummaryCard> {
  final repository = AttachmentRepository.instance;
  late Future<List<AcademicAttachment>> future;

  @override
  void initState() {
    super.initState();
    future = repository.forTarget(widget.target);
  }

  Future<void> _openManager() async {
    await showAttachmentManager(context, target: widget.target, title: widget.title);
    if (!mounted) return;
    setState(() => future = repository.forTarget(widget.target));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AcademicAttachment>>(
      future: future,
      builder: (context, snapshot) {
        final items = snapshot.data ?? const <AcademicAttachment>[];
        if (widget.compact) {
          return OutlinedButton.icon(
            onPressed: _openManager,
            icon: const Icon(Icons.attach_file_rounded),
            label: Text(items.isEmpty ? 'Anexos' : 'Anexos (${items.length})'),
          );
        }
        return SoftCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.attach_file_rounded, size: 18, color: AppColors.gold),
                  const SizedBox(width: 7),
                  const Expanded(child: Text('Anexos', style: TextStyle(fontWeight: FontWeight.w900))),
                  TextButton.icon(
                    onPressed: _openManager,
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: Text(items.isEmpty ? 'Adicionar' : 'Gerenciar'),
                  ),
                ],
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(minHeight: 3),
                )
              else if (items.isEmpty)
                Text('Nenhuma foto ou arquivo anexado a este item.', style: Theme.of(context).textTheme.bodySmall)
              else ...[
                const SizedBox(height: 4),
                for (final item in items.take(3))
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(_icon(item.kind), size: 20),
                    title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(attachmentKindLabel(item.kind)),
                    onTap: _openManager,
                  ),
                if (items.length > 3)
                  TextButton(
                    onPressed: _openManager,
                    child: Text('Ver mais ${items.length - 3} anexo${items.length - 3 == 1 ? '' : 's'}'),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

IconData _icon(AttachmentKind kind) => switch (kind) {
      AttachmentKind.image => Icons.image_outlined,
      AttachmentKind.pdf => Icons.picture_as_pdf_outlined,
      AttachmentKind.document => Icons.description_outlined,
      AttachmentKind.archive => Icons.folder_zip_outlined,
      AttachmentKind.other => Icons.insert_drive_file_outlined,
    };
