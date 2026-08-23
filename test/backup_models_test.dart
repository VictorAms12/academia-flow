import 'package:academia_flow/models/backup_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backupKindFromName tolera valor desconhecido', () {
    expect(backupKindFromName('automatic'), BackupKind.automatic);
    expect(backupKindFromName('safety'), BackupKind.safety);
    expect(backupKindFromName('qualquer'), BackupKind.manual);
    expect(backupKindFromName(null), BackupKind.manual);
  });

  test('BackupPreview expõe contagens acadêmicas com defaults seguros', () {
    final preview = BackupPreview(
      sourcePath: '/tmp/teste.afbackup',
      fileName: 'teste.afbackup',
      formatVersion: 1,
      appVersion: '2.6.5+24',
      createdAt: DateTime(2026, 8, 23, 14),
      kind: BackupKind.manual,
      counts: const {
        'subjects': 5,
        'tasks': 12,
        'notes': 4,
        'materials': 3,
        'attachments': 8,
        'class_sessions': 30,
      },
      attachmentBytes: 2048,
      archiveBytes: 4096,
      dataSha256: 'a' * 64,
      missingAttachments: 0,
      integrityValid: true,
    );

    expect(preview.subjects, 5);
    expect(preview.tasks, 12);
    expect(preview.notes, 4);
    expect(preview.materials, 3);
    expect(preview.attachments, 8);
    expect(preview.sessions, 30);
    expect(preview.academicItems, 54);
    expect(preview.integrityValid, isTrue);
  });
}
