import 'package:academia_flow/integrations/google/google_integration_controller.dart';
import 'package:academia_flow/integrations/google/google_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normaliza nomes de turma para sugerir matéria existente', () {
    expect(
      GoogleIntegrationController.normalizeCourseName('Banco de Dados - ADS 2026/2'),
      'banco de dados',
    );
  });

  test('interpreta prazo do Classroom como instante UTC', () {
    final work = ClassroomCourseWork.fromJson({
      'courseId': '1',
      'id': '2',
      'title': 'Trabalho',
      'dueDate': {'year': 2026, 'month': 8, 'day': 21},
      'dueTime': {'hours': 23, 'minutes': 59},
    });
    expect(work.dueAt, isNotNull);
    expect(work.dueAt!.toUtc(), DateTime.utc(2026, 8, 21, 23, 59));
  });

  test('TURNED_IN e RETURNED contam como entregues', () {
    expect(const ClassroomSubmission(courseWorkId: '1', state: 'TURNED_IN').submitted, isTrue);
    expect(const ClassroomSubmission(courseWorkId: '1', state: 'RETURNED').submitted, isTrue);
    expect(const ClassroomSubmission(courseWorkId: '1', state: 'CREATED').submitted, isFalse);
  });
}
