import 'package:academia_flow/models/models.dart';
import 'package:academia_flow/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Academia Flow 2.7 regressions', () {
    test('matéria sem histórico não é tratada como tendo frequência medida', () {
      const empty = Subject(name: 'Sem histórico');
      const measured = Subject(name: 'Com histórico', totalClasses: 20, absences: 2);

      expect(empty.hasAttendanceHistory, isFalse);
      expect(measured.hasAttendanceHistory, isTrue);
      expect(measured.attendance, 90);
    });

    test('momento da conclusão sobrevive à serialização da atividade', () {
      final completedAt = DateTime(2026, 9, 2, 14, 30);
      final task = AcademicTask(
        title: 'Entregar projeto',
        dueDate: DateTime(2026, 9, 2),
        status: TaskStatus.done,
        completedAt: completedAt,
      );

      final restored = AcademicTask.fromMap(task.toMap());
      expect(restored.completedAt, completedAt);
      expect(restored.status, TaskStatus.done);
    });

    test('taxa no prazo usa conclusão real e ignora histórico legado sem timestamp', () {
      final state = AppState();
      state.tasks = [
        AcademicTask(
          id: 1,
          title: 'No prazo',
          dueDate: DateTime(2026, 9, 2),
          status: TaskStatus.done,
          completedAt: DateTime(2026, 9, 2, 18),
        ),
        AcademicTask(
          id: 2,
          title: 'Atrasada',
          dueDate: DateTime(2026, 9, 2),
          status: TaskStatus.done,
          completedAt: DateTime(2026, 9, 3, 8),
        ),
        AcademicTask(
          id: 3,
          title: 'Legado',
          dueDate: DateTime(2026, 9, 1),
          status: TaskStatus.done,
        ),
      ];

      expect(state.taskCompletionRate, 100);
      expect(state.onTimeTaskRate, 50);
    });

    test('selecionar novamente a mesma tela não notifica toda a árvore', () {
      final state = AppState();
      var notifications = 0;
      state.addListener(() => notifications++);

      state.setIndex(0);
      expect(notifications, 0);

      state.setIndex(2);
      expect(state.currentIndex, 2);
      expect(notifications, 1);

      state.setIndex(2);
      expect(notifications, 1);
    });

    test('copyWith permite reabrir atividade removendo completedAt', () {
      final task = AcademicTask(
        title: 'Teste',
        dueDate: DateTime(2026, 9, 2),
        status: TaskStatus.done,
        completedAt: DateTime(2026, 9, 2, 12),
      );

      final reopened = task.copyWith(
        status: TaskStatus.todo,
        clearCompletedAt: true,
      );

      expect(reopened.status, TaskStatus.todo);
      expect(reopened.completedAt, isNull);
    });
  });
}
