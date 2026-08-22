enum AttachmentTargetType { classSession, note, material, task }

enum AttachmentKind { image, pdf, document, archive, other }

class AttachmentTarget {
  const AttachmentTarget({
    required this.type,
    required this.id,
    this.subjectId,
  });

  final AttachmentTargetType type;
  final int id;
  final int? subjectId;

  Map<String, Object?> toColumns() => {
        'session_id': type == AttachmentTargetType.classSession ? id : null,
        'note_id': type == AttachmentTargetType.note ? id : null,
        'material_id': type == AttachmentTargetType.material ? id : null,
        'task_id': type == AttachmentTargetType.task ? id : null,
        'subject_id': subjectId,
      };
}

class AcademicAttachment {
  const AcademicAttachment({
    this.id,
    required this.targetType,
    required this.targetId,
    this.subjectId,
    required this.title,
    required this.fileName,
    required this.storedPath,
    required this.kind,
    this.mimeType = '',
    this.sizeBytes = 0,
    required this.createdAt,
  });

  final int? id;
  final AttachmentTargetType targetType;
  final int targetId;
  final int? subjectId;
  final String title;
  final String fileName;
  final String storedPath;
  final AttachmentKind kind;
  final String mimeType;
  final int sizeBytes;
  final DateTime createdAt;

  AttachmentTarget get target => AttachmentTarget(type: targetType, id: targetId, subjectId: subjectId);

  AcademicAttachment copyWith({
    int? id,
    String? title,
    String? fileName,
    String? storedPath,
    AttachmentKind? kind,
    String? mimeType,
    int? sizeBytes,
    DateTime? createdAt,
  }) =>
      AcademicAttachment(
        id: id ?? this.id,
        targetType: targetType,
        targetId: targetId,
        subjectId: subjectId,
        title: title ?? this.title,
        fileName: fileName ?? this.fileName,
        storedPath: storedPath ?? this.storedPath,
        kind: kind ?? this.kind,
        mimeType: mimeType ?? this.mimeType,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        ...target.toColumns(),
        'title': title,
        'file_name': fileName,
        'stored_path': storedPath,
        'kind': kind.index,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
        'created_at': createdAt.toIso8601String(),
      };

  factory AcademicAttachment.fromMap(Map<String, Object?> map) {
    final sessionId = (map['session_id'] as num?)?.toInt();
    final noteId = (map['note_id'] as num?)?.toInt();
    final materialId = (map['material_id'] as num?)?.toInt();
    final taskId = (map['task_id'] as num?)?.toInt();

    final (type, targetId) = sessionId != null
        ? (AttachmentTargetType.classSession, sessionId)
        : noteId != null
            ? (AttachmentTargetType.note, noteId)
            : materialId != null
                ? (AttachmentTargetType.material, materialId)
                : (AttachmentTargetType.task, taskId ?? 0);

    final rawKind = (map['kind'] as num?)?.toInt() ?? AttachmentKind.other.index;
    final kind = rawKind >= 0 && rawKind < AttachmentKind.values.length
        ? AttachmentKind.values[rawKind]
        : AttachmentKind.other;

    return AcademicAttachment(
      id: (map['id'] as num?)?.toInt(),
      targetType: type,
      targetId: targetId,
      subjectId: (map['subject_id'] as num?)?.toInt(),
      title: '${map['title'] ?? ''}',
      fileName: '${map['file_name'] ?? ''}',
      storedPath: '${map['stored_path'] ?? ''}',
      kind: kind,
      mimeType: '${map['mime_type'] ?? ''}',
      sizeBytes: (map['size_bytes'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse('${map['created_at'] ?? ''}') ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

AttachmentKind attachmentKindForName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.heic') ||
      lower.endsWith('.heif')) {
    return AttachmentKind.image;
  }
  if (lower.endsWith('.pdf')) return AttachmentKind.pdf;
  if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z') || lower.endsWith('.tar') || lower.endsWith('.gz')) {
    return AttachmentKind.archive;
  }
  if (lower.endsWith('.doc') ||
      lower.endsWith('.docx') ||
      lower.endsWith('.xls') ||
      lower.endsWith('.xlsx') ||
      lower.endsWith('.ppt') ||
      lower.endsWith('.pptx') ||
      lower.endsWith('.txt') ||
      lower.endsWith('.csv') ||
      lower.endsWith('.md') ||
      lower.endsWith('.odt') ||
      lower.endsWith('.ods') ||
      lower.endsWith('.odp')) {
    return AttachmentKind.document;
  }
  return AttachmentKind.other;
}

String attachmentKindLabel(AttachmentKind kind) => switch (kind) {
      AttachmentKind.image => 'Imagem',
      AttachmentKind.pdf => 'PDF',
      AttachmentKind.document => 'Documento',
      AttachmentKind.archive => 'Arquivo compactado',
      AttachmentKind.other => 'Arquivo',
    };

String attachmentTargetLabel(AttachmentTargetType type) => switch (type) {
      AttachmentTargetType.classSession => 'Aula',
      AttachmentTargetType.note => 'Anotação',
      AttachmentTargetType.material => 'Material',
      AttachmentTargetType.task => 'Atividade',
    };
