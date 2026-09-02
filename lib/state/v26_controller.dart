import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/app_database.dart';
import '../models/models.dart';
import '../models/v26_models.dart';
import 'app_state.dart';

class V26Controller extends ChangeNotifier {
  V26Controller._();
  static final V26Controller instance = V26Controller._();

  final AppDatabase _db = AppDatabase.instance;
  AppState? _state;
  bool _initialized = false;
  bool loading = false;
  List<StudyBlock> studyBlocks = [];
  Set<String> dismissedInsights = <String>{};

  bool get initialized => _initialized;

  Future<void> initialize(AppState state) async {
    _state = state;
    if (_initialized || loading) return;
    loading = true;
    notifyListeners();
    try {
      final settings = await _db.getSettings();
      studyBlocks = StudyBlock.decodeList(settings['study_blocks_v26']);
      dismissedInsights = _decodeStringSet(settings['dismissed_insights_v26']);
      _initialized = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void bind(AppState state) => _state = state;

  Future<void> clearAcademicState() async {
    studyBlocks = [];
    dismissedInsights = <String>{};
    await Future.wait([
      _db.setSetting('study_blocks_v26', '[]'),
      _db.setSetting('dismissed_insights_v26', '[]'),
    ]);
    notifyListeners();
  }

  void resetLocalState() {
    _state = null;
    _initialized = false;
    loading = false;
    studyBlocks = [];
    dismissedInsights = <String>{};
    notifyListeners();
  }

  List<StudyBlock> studyBlocksForDate(DateTime date) {
    final items = studyBlocks.where((block) => _sameDay(block.startsAt, date)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return items;
  }

  List<StudyBlock> get upcomingStudyBlocks {
    final now = DateTime.now();
    final items = studyBlocks.where((block) => !block.completed && block.endsAt.isAfter(now)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return items;
  }

  Future<StudyBlock> saveStudyBlock({
    StudyBlock? existing,
    required String title,
    required DateTime startsAt,
    int? subjectId,
    required int durationMinutes,
    String note = '',
  }) async {
    final block = StudyBlock(
      id: existing?.id ?? 'sb-${DateTime.now().microsecondsSinceEpoch}',
      title: title.trim(),
      startsAt: startsAt,
      subjectId: subjectId,
      durationMinutes: durationMinutes.clamp(15, 720).toInt(),
      completed: existing?.completed ?? false,
      note: note.trim(),
    );
    if (block.title.isEmpty) throw ArgumentError('Informe um título para o bloco de estudo.');
    final index = studyBlocks.indexWhere((item) => item.id == block.id);
    if (index < 0) {
      studyBlocks = [...studyBlocks, block];
    } else {
      final next = [...studyBlocks];
      next[index] = block;
      studyBlocks = next;
    }
    _sortBlocks();
    await _persistStudyBlocks();
    notifyListeners();
    return block;
  }

  Future<void> toggleStudyBlock(StudyBlock block) async {
    final index = studyBlocks.indexWhere((item) => item.id == block.id);
    if (index < 0) return;
    final next = [...studyBlocks];
    next[index] = next[index].copyWith(completed: !next[index].completed);
    studyBlocks = next;
    await _persistStudyBlocks();
    notifyListeners();
  }

  Future<void> deleteStudyBlock(StudyBlock block) async {
    studyBlocks = studyBlocks.where((item) => item.id != block.id).toList();
    await _persistStudyBlocks();
    notifyListeners();
  }

  Future<AcademicTask> duplicateTask(AcademicTask task) async {
    final state = _requireState();
    return state.saveTask(
      AcademicTask(
        title: '${task.title} (cópia)',
        subjectId: task.subjectId,
        dueDate: task.dueDate,
        priority: task.priority,
        status: TaskStatus.todo,
        kind: task.kind,
        reminderEnabled: task.reminderEnabled,
        description: task.description,
        checklist: [...task.checklist],
        completedSteps: const [],
      ),
    );
  }

  Future<AcademicTask> postponeTask(AcademicTask task, Duration duration) async {
    final state = _requireState();
    if (task.status == TaskStatus.done) return task;
    return state.saveTask(task.copyWith(dueDate: task.dueDate.add(duration)));
  }

  Future<AcademicNote> saveQuickClassNote(ClassSession session, String content) async {
    final state = _requireState();
    final text = content.trim();
    if (text.isEmpty) throw ArgumentError('Digite uma anotação.');
    final subject = state.subjectName(session.subjectId);
    final date = session.date;
    return state.saveNote(
      AcademicNote(
        subjectId: session.subjectId,
        title: 'Aula de $subject • ${_dateLabel(date)}',
        content: text,
        tags: 'aula, nota rápida',
        createdAt: DateTime.now(),
        sessionId: session.id,
      ),
    );
  }

  Future<void> changeAttendance(
    ClassSession session,
    AttendanceStatus status, {
    String? note,
  }) async {
    final state = _requireState();
    final latest = state.sessionById(session.id) ?? session;
    if ((status == AttendanceStatus.present || status == AttendanceStatus.absent) && latest.startsAt.isAfter(DateTime.now())) {
      throw StateError('Presença e falta só podem ser registradas após o início da aula.');
    }
    await state.markAttendance(latest, status);
    if (note != null) {
      final refreshed = state.sessionById(latest.id) ?? latest.copyWith(status: status);
      await state.saveClassSession(refreshed.copyWith(note: note.trim()));
    }
  }

  Future<void> undoAttendance(ClassSession previous) async {
    if (previous.id == null) return;
    final state = _requireState();
    final current = state.sessionById(previous.id) ?? previous;
    await state.markAttendance(current, previous.status);
    final refreshed = state.sessionById(previous.id) ?? previous;
    if (refreshed.note != previous.note) {
      await state.saveClassSession(refreshed.copyWith(note: previous.note));
    }
  }

  List<AcademicTask> prioritizedTasks({int limit = 20}) {
    final state = _state;
    if (state == null) return [];
    final items = state.tasks.where((task) => task.status != TaskStatus.done).toList()
      ..sort((a, b) {
        final urgency = taskUrgencyScore(b).compareTo(taskUrgencyScore(a));
        if (urgency != 0) return urgency;
        return a.dueDate.compareTo(b.dueDate);
      });
    return items.take(limit).toList();
  }

  int dailyLoadScore(DateTime date) {
    final state = _state;
    if (state == null) return 0;
    final sessions = state.sessionsForDate(date).where((s) => s.status != AttendanceStatus.cancelled);
    final tasks = state.tasks.where((task) => task.status != TaskStatus.done && _sameDay(task.dueDate, date));
    final study = studyBlocksForDate(date).where((block) => !block.completed);
    final classPoints = sessions.fold<int>(0, (sum, session) => sum + session.classCount * 9);
    final taskPoints = tasks.fold<int>(0, (sum, task) => sum + switch (task.priority) { Priority.high => 22, Priority.medium => 14, Priority.low => 8 });
    final studyPoints = study.fold<int>(0, (sum, block) => sum + (block.durationMinutes / 15).ceil());
    return (classPoints + taskPoints + studyPoints).clamp(0, 100).toInt();
  }

  String dailyLoadLabel(DateTime date) {
    final score = dailyLoadScore(date);
    if (score >= 70) return 'Alta';
    if (score >= 38) return 'Média';
    return 'Leve';
  }

  List<AcademicInsight> activeInsights(AppState state) {
    _state = state;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final insights = <AcademicInsight>[];

    for (final session in state.pendingAttendance.take(3)) {
      if (session.id == null) continue;
      insights.add(AcademicInsight(
        id: 'attendance-${session.id}',
        title: 'Presença pendente',
        message: '${state.subjectName(session.subjectId)} • ${_dateLabel(session.date)} às ${session.start}',
        kind: InsightKind.attendance,
        severity: session.endsAt.isBefore(now) ? InsightSeverity.attention : InsightSeverity.info,
        at: session.startsAt,
        entityId: session.id,
      ));
    }

    final overdue = state.tasks.where((task) {
      if (task.id == null || task.status == TaskStatus.done) return false;
      final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
      return due.isBefore(today);
    }).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    for (final task in overdue.take(3)) {
      insights.add(AcademicInsight(
        id: 'overdue-${task.id}-${_dateKey(task.dueDate)}',
        title: 'Prazo atrasado',
        message: '${task.title} • ${state.subjectName(task.subjectId)}',
        kind: InsightKind.task,
        severity: InsightSeverity.critical,
        at: task.dueDate,
        entityId: task.id,
      ));
    }

    for (final task in state.tasks.where((task) => task.status != TaskStatus.done && task.kind == TaskKind.exam)) {
      final days = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day).difference(today).inDays;
      if (days < 0 || days > 7 || task.id == null) continue;
      insights.add(AcademicInsight(
        id: 'exam-${task.id}-${_dateKey(task.dueDate)}',
        title: days == 0 ? 'Prova hoje' : 'Prova em $days dia${days == 1 ? '' : 's'}',
        message: '${task.title} • ${state.subjectName(task.subjectId)}',
        kind: InsightKind.exam,
        severity: days <= 1 ? InsightSeverity.critical : InsightSeverity.attention,
        at: task.dueDate,
        entityId: task.id,
      ));
    }

    for (final subject in state.subjects.where(state.isSubjectAtRisk).take(3)) {
      if (subject.id == null) continue;
      final remaining = state.remainingAbsences(subject);
      insights.add(AcademicInsight(
        id: 'risk-${subject.id}-${subject.absences}-${subject.totalClasses}',
        title: 'Atenção em ${subject.name}',
        message: remaining >= 9999
            ? 'A frequência ou média está próxima do limite configurado.'
            : 'Frequência ${subject.attendance.toStringAsFixed(1)}% • $remaining falta${remaining == 1 ? '' : 's'} restante${remaining == 1 ? '' : 's'}.',
        kind: InsightKind.performance,
        severity: remaining <= 1 ? InsightSeverity.critical : InsightSeverity.attention,
        entityId: subject.id,
      ));
    }

    final nextStudy = upcomingStudyBlocks.where((block) => block.startsAt.difference(now).inHours <= 24).take(2);
    for (final block in nextStudy) {
      insights.add(AcademicInsight(
        id: 'study-${block.id}-${_dateKey(block.startsAt)}',
        title: 'Bloco de estudo programado',
        message: '${block.title} • ${_timeLabel(block.startsAt)} • ${compactDuration(block.durationMinutes)}',
        kind: InsightKind.study,
        severity: InsightSeverity.info,
        at: block.startsAt,
      ));
    }

    insights.removeWhere((item) => dismissedInsights.contains(item.id));
    insights.sort((a, b) {
      final severity = _severityWeight(b.severity).compareTo(_severityWeight(a.severity));
      if (severity != 0) return severity;
      final aa = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bb = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aa.compareTo(bb);
    });
    return insights;
  }

  Future<void> dismissInsight(String id) async {
    dismissedInsights = {...dismissedInsights, id};
    if (dismissedInsights.length > 120) {
      dismissedInsights = dismissedInsights.skip(dismissedInsights.length - 100).toSet();
    }
    await _db.setSetting('dismissed_insights_v26', jsonEncode(dismissedInsights.toList()));
    notifyListeners();
  }

  Future<void> restoreInsights() async {
    dismissedInsights = <String>{};
    await _db.setSetting('dismissed_insights_v26', '[]');
    notifyListeners();
  }

  Future<void> _persistStudyBlocks() => _db.setSetting('study_blocks_v26', StudyBlock.encodeList(studyBlocks));

  void _sortBlocks() => studyBlocks.sort((a, b) => a.startsAt.compareTo(b.startsAt));

  AppState _requireState() {
    final state = _state;
    if (state == null) throw StateError('A Rotina Inteligente ainda não foi inicializada.');
    return state;
  }
}

Set<String> _decodeStringSet(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <String>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String>{};
    return decoded.map((item) => '$item').where((item) => item.isNotEmpty).toSet();
  } catch (_) {
    return <String>{};
  }
}

int _severityWeight(InsightSeverity value) => switch (value) {
      InsightSeverity.critical => 4,
      InsightSeverity.attention => 3,
      InsightSeverity.info => 2,
      InsightSeverity.success => 1,
    };

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _dateLabel(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
String _timeLabel(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
