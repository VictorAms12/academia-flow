enum BackupKind { manual, automatic, safety }

String backupKindLabel(BackupKind kind) => switch (kind) {
      BackupKind.manual => 'Manual',
      BackupKind.automatic => 'Automático',
      BackupKind.safety => 'Segurança',
    };

class BackupPreview {
  const BackupPreview({
    required this.sourcePath,
    required this.fileName,
    required this.formatVersion,
    required this.appVersion,
    required this.createdAt,
    required this.kind,
    required this.counts,
    required this.attachmentBytes,
    required this.archiveBytes,
    required this.dataSha256,
    required this.missingAttachments,
    required this.integrityValid,
  });

  final String sourcePath;
  final String fileName;
  final int formatVersion;
  final String appVersion;
  final DateTime createdAt;
  final BackupKind kind;
  final Map<String, int> counts;
  final int attachmentBytes;
  final int archiveBytes;
  final String dataSha256;
  final int missingAttachments;
  final bool integrityValid;

  int get subjects => counts['subjects'] ?? 0;
  int get tasks => counts['tasks'] ?? 0;
  int get notes => counts['notes'] ?? 0;
  int get materials => counts['materials'] ?? 0;
  int get attachments => counts['attachments'] ?? 0;
  int get sessions => counts['class_sessions'] ?? 0;

  int get academicItems => subjects + tasks + notes + materials + sessions;
}

BackupKind backupKindFromName(String? value) => switch (value) {
      'automatic' => BackupKind.automatic,
      'safety' => BackupKind.safety,
      _ => BackupKind.manual,
    };
