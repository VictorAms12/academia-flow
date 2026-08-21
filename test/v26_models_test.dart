import 'package:academia_flow/models/models.dart';
import 'package:academia_flow/models/v26_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudyBlock', () {
    test('serializa e restaura uma lista', () {
      final input = [
        StudyBlock(
          id: 'a',
          title: 'Revisar SQL',
          startsAt: DateTime(2026, 8, 21, 14, 30),
          subjectId: 4,
          durationMinutes: 90,
          note: 'JOIN e GROUP BY',
        ),
      ];

      final restored = StudyBlock.decodeList(StudyBlock.encodeList(input));
      expect(restored, hasLength(1));
      expect(restored.first.id, 'a');
      expect(restored.first.title, 'Revisar SQL');
      expect(restored.first.durationMinutes, 90);
      expect(restored.first.subjectId, 4);
      expect(restored.first.startsAt, DateTime(2026, 8, 21, 14, 30));
    });

    test('ignora itens corrompidos sem perder itens válidos', () {
      const raw = '[{"id":"ok","title":"POO","startsAt":"2026-08-21T10:00:00","durationMinutes":60},{"id":"bad","title":"X","startsAt":"invalida"}]';
      final restored = StudyBlock.decodeList(raw);
      expect(restored, hasLength(1));
      expect(restored.first.id, 'ok');
    });
  });

  group('priorização', () {
    AcademicTask task(String title, DateTime due, Priority priority) => AcademicTask(
          title: title,
          dueDate: due,
          priority: priority,
        );

    test('atividade atrasada supera atividade distante', () {
      final now = DateTime(2026, 8, 20, 12);
      final overdue = task('Atrasada', DateTime(2026, 8, 19), Priority.low);
      final future = task('Distante', DateTime(2026, 9, 10), Priority.high);
      expect(taskUrgencyScore(overdue, now: now), greaterThan(taskUrgencyScore(future, now: now)));
    });

    test('atividade concluída sai do ranking', () {
      final done = AcademicTask(
        title: 'Feita',
        dueDate: DateTime(2026, 8, 20),
        status: TaskStatus.done,
      );
      expect(taskUrgencyScore(done, now: DateTime(2026, 8, 20)), lessThan(0));
    });
  });

  test('compactDuration formata minutos e horas', () {
    expect(compactDuration(45), '45min');
    expect(compactDuration(60), '1h');
    expect(compactDuration(90), '1h 30min');
  });
}
