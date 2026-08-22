import 'package:academia_flow/models/attachment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('attachmentKindForName', () {
    test('classifica imagens e PDFs', () {
      expect(attachmentKindForName('quadro.JPG'), AttachmentKind.image);
      expect(attachmentKindForName('lista.pdf'), AttachmentKind.pdf);
    });

    test('classifica documentos e compactados', () {
      expect(attachmentKindForName('trabalho.docx'), AttachmentKind.document);
      expect(attachmentKindForName('fontes.zip'), AttachmentKind.archive);
      expect(attachmentKindForName('arquivo.bin'), AttachmentKind.other);
    });
  });

  test('AttachmentTarget preenche somente o vinculo correto', () {
    const target = AttachmentTarget(type: AttachmentTargetType.note, id: 42, subjectId: 7);
    final columns = target.toColumns();
    expect(columns['note_id'], 42);
    expect(columns['session_id'], isNull);
    expect(columns['material_id'], isNull);
    expect(columns['task_id'], isNull);
    expect(columns['subject_id'], 7);
  });

  test('AcademicAttachment reconstrói o alvo pelo mapa', () {
    final item = AcademicAttachment.fromMap({
      'id': 1,
      'subject_id': 3,
      'session_id': 10,
      'note_id': null,
      'material_id': null,
      'task_id': null,
      'title': 'Foto do quadro',
      'file_name': 'quadro.jpg',
      'stored_path': '1_quadro.jpg',
      'kind': AttachmentKind.image.index,
      'mime_type': 'image/jpeg',
      'size_bytes': 1024,
      'created_at': '2026-08-21T20:00:00.000',
    });
    expect(item.targetType, AttachmentTargetType.classSession);
    expect(item.targetId, 10);
    expect(item.subjectId, 3);
  });
}
