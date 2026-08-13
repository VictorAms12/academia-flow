import 'package:flutter_test/flutter_test.dart';
import 'package:academia_flow/models/models.dart';

void main() {
  test('frequência da matéria é calculada corretamente', () {
    const subject = Subject(
      name: 'Teste',
      totalClasses: 20,
      absences: 2,
    );
    expect(subject.attendance, 90.0);
  });

  test('atividade mantém checklist na serialização', () {
    final task = AcademicTask(
      title: 'Trabalho',
      dueDate: DateTime(2026, 8, 20),
      checklist: const ['Pesquisar', 'Escrever'],
      completedSteps: const [0],
    );
    final restored = AcademicTask.fromMap({
      ...task.toMap(),
      'id': 1,
    });
    expect(restored.checklist.length, 2);
    expect(restored.completedSteps, [0]);
  });
}
