import 'package:academia_flow/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AcademicTask tolera enum e JSON legados inválidos', () {
    final task = AcademicTask.fromMap({
      'id': 1,
      'title': 'Atividade',
      'subject_id': null,
      'due_date': '2026-08-18T00:00:00.000',
      'priority': 99,
      'status': -4,
      'kind': 999,
      'reminder_enabled': 1,
      'description': '',
      'checklist': '{quebrado',
      'completed_steps': '[0, 20, "x"]',
      'session_id': null,
    });

    expect(task.priority, Priority.medium);
    expect(task.status, TaskStatus.todo);
    expect(task.kind, TaskKind.activity);
    expect(task.checklist, isEmpty);
    expect(task.completedSteps, isEmpty);
  });

  test('ClassSession saneia status, tipo, quantidade e horários inválidos', () {
    final session = ClassSession.fromMap({
      'id': 4,
      'subject_id': 2,
      'schedule_id': null,
      'date': '2026-08-18',
      'start_time': '99:90',
      'end_time': 'texto',
      'room': '',
      'class_count': 0,
      'status': 100,
      'kind': -1,
      'note': '',
      'makeup_for_session_id': null,
      'created_at': '2026-08-18T10:00:00.000',
    });

    expect(session.status, AttendanceStatus.pending);
    expect(session.kind, ClassSessionKind.regular);
    expect(session.classCount, 1);
    expect(session.start, '00:00');
    expect(session.end, '00:01');
  });

  test('Checklist remove índices concluídos inexistentes', () {
    final task = AcademicTask.fromMap({
      'id': 1,
      'title': 'Lista',
      'due_date': '2026-08-18',
      'priority': Priority.medium.index,
      'status': TaskStatus.todo.index,
      'kind': TaskKind.activity.index,
      'reminder_enabled': 1,
      'description': '',
      'checklist': '["A", "B"]',
      'completed_steps': '[1, 9, 1, -1]',
    });

    expect(task.completedSteps, [1]);
  });
}
