import 'package:academia_flow/models/models.dart';
import 'package:academia_flow/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('média de frequência ignora matéria sem histórico', () {
    final state = AppState();
    state.subjects = const [
      Subject(id: 1, name: 'Sem histórico'),
      Subject(id: 2, name: 'Com histórico', totalClasses: 10, absences: 2),
    ];

    expect(state.averageAttendance, closeTo(80, 0.001));
  });

  test('resumo semanal não conta aula futura como pendente', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final futureStart = now.add(const Duration(minutes: 2));
    final futureEnd = futureStart.add(const Duration(hours: 1));

    String hhmm(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

    final state = AppState();
    state.classSessions = [
      ClassSession(
        id: 1,
        subjectId: 1,
        date: today,
        start: '00:00',
        end: '00:01',
        classCount: 2,
        status: AttendanceStatus.present,
        createdAt: now,
      ),
      ClassSession(
        id: 2,
        subjectId: 1,
        date: today,
        start: '00:00',
        end: '00:01',
        classCount: 1,
        status: AttendanceStatus.pending,
        createdAt: now,
      ),
      ClassSession(
        id: 3,
        subjectId: 1,
        date: futureStart,
        start: hhmm(futureStart),
        end: hhmm(futureEnd),
        classCount: 3,
        status: AttendanceStatus.pending,
        createdAt: now,
      ),
    ];

    final summary = state.weeklyAttendanceSummary;
    expect(summary['classes'], 3);
    expect(summary['present'], 2);
    expect(summary['pending'], 1);
    expect(summary['absent'], 0);
  });

  test('índice de navegação é limitado às cinco telas principais', () {
    final state = AppState();
    state.setIndex(99);
    expect(state.currentIndex, 4);
    state.setIndex(-5);
    expect(state.currentIndex, 0);
  });
}
