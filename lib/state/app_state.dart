import 'dart:async';

import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../models/models.dart';
import '../services/notification_service.dart';

class AppState extends ChangeNotifier {
  final AppDatabase _db = AppDatabase.instance;
  final NotificationService notifications = NotificationService.instance;

  bool isDark = true;
  int currentIndex = 0;
  bool kanbanMode = true;
  String userName = '';
  String course = '';
  String period = '';
  String semester = '';
  double minGrade = 6.0;
  double minAttendance = 75.0;

  bool classRemindersEnabled = true;
  bool attendanceCheckInEnabled = true;
  bool endPendingReminderEnabled = true;
  bool endClassActionsEnabled = false;
  bool streakEnabled = true;
  int? highlightedSessionId;

  List<Subject> subjects = [];
  List<AcademicTask> tasks = [];
  List<Grade> grades = [];
  List<ScheduleEntry> schedules = [];
  List<ClassSession> classSessions = [];
  List<AcademicCalendarEvent> calendarEvents = [];
  List<AcademicNote> notes = [];
  List<MaterialResource> materials = [];

  final Map<int, int> _baselineTotalClasses = {};
  final Map<int, int> _baselineAbsences = {};
  final Map<String, Future<dynamic>> _pendingCreates = {};

  bool get onboardingComplete => userName.trim().isNotEmpty && course.trim().isNotEmpty;

  Future<void> initialize() async {
    await _db.database;
    final settings = await _db.getSettings();
    userName = settings['user_name'] ?? '';
    course = settings['course'] ?? '';
    period = settings['period'] ?? '';
    semester = settings['semester'] ?? '';
    isDark = (settings['dark_mode'] ?? 'true') == 'true';
    minGrade = double.tryParse(settings['min_grade'] ?? '') ?? 6.0;
    minAttendance = double.tryParse(settings['min_attendance'] ?? '') ?? 75.0;
    classRemindersEnabled = (settings['class_reminders'] ?? 'true') == 'true';
    attendanceCheckInEnabled = (settings['attendance_checkin'] ?? 'true') == 'true';
    endPendingReminderEnabled = (settings['end_pending_reminder'] ?? 'true') == 'true';
    endClassActionsEnabled = (settings['end_class_actions'] ?? 'false') == 'true';
    streakEnabled = (settings['attendance_streak'] ?? 'true') == 'true';

    await reloadAll(notify: false);
    notifications.onRoutineAction = _handleRoutineAction;
    notifications.onNotificationTap = _handleNotificationTap;
    await notifications.initialize();
    unawaited(_finishStartupWork());
  }

  Future<void> _finishStartupWork() async {
    try {
      await ensureRoutineSessions();
      await _rescheduleNotifications();
    } catch (error) {
      notifications.lastError = 'Falha ao concluir tarefas pós-inicialização: $error';
    }
  }

  Future<void> reloadAll({bool notify = true}) async {
    final rawSubjects = await _db.getSubjects();
    _captureSubjectBaselines(rawSubjects);
    subjects = rawSubjects;
    tasks = await _db.getTasks();
    grades = await _db.getGrades();
    schedules = await _db.getSchedules();
    classSessions = await _db.getClassSessions();
    calendarEvents = await _db.getCalendarEvents();
    notes = await _db.getNotes();
    materials = await _db.getMaterials();
    _projectAttendanceIntoSubjects();
    if (notify) notifyListeners();
  }

  void _captureSubjectBaselines(List<Subject> raw) {
    _baselineTotalClasses
      ..clear()
      ..addEntries(raw.where((s) => s.id != null).map((s) => MapEntry(s.id!, s.totalClasses)));
    _baselineAbsences
      ..clear()
      ..addEntries(raw.where((s) => s.id != null).map((s) => MapEntry(s.id!, s.absences)));
  }

  void _projectAttendanceIntoSubjects() {
    final sessionsBySubject = <int, List<ClassSession>>{};
    for (final session in classSessions) {
      (sessionsBySubject[session.subjectId] ??= []).add(session);
    }
    subjects = subjects.map((subject) {
      if (subject.id == null) return subject;
      final baseTotal = _baselineTotalClasses[subject.id!] ?? subject.totalClasses;
      final baseAbsences = _baselineAbsences[subject.id!] ?? subject.absences;
      final resolved = (sessionsBySubject[subject.id!] ?? const <ClassSession>[]).where(
        (s) => s.status == AttendanceStatus.present || s.status == AttendanceStatus.absent,
      );
      final sessionTotal = resolved.fold<int>(0, (v, s) => v + s.classCount);
      final sessionAbsences = resolved
          .where((s) => s.status == AttendanceStatus.absent)
          .fold<int>(0, (v, s) => v + s.classCount);
      return subject.copyWith(
        totalClasses: baseTotal + sessionTotal,
        absences: baseAbsences + sessionAbsences,
      );
    }).toList();
  }

  Future<void> saveProfile({required String name, required String courseName, required String periodName, required String semesterName}) async {
    userName = name.trim();
    course = courseName.trim();
    period = periodName.trim();
    semester = semesterName.trim();
    await Future.wait([
      _db.setSetting('user_name', userName),
      _db.setSetting('course', course),
      _db.setSetting('period', period),
      _db.setSetting('semester', semester),
    ]);
    notifyListeners();
  }

  Future<void> updateThresholds(double grade, double attendance) async {
    minGrade = grade.clamp(0, 10).toDouble();
    minAttendance = attendance.clamp(0, 100).toDouble();
    await Future.wait([
      _db.setSetting('min_grade', '$minGrade'),
      _db.setSetting('min_attendance', '$minAttendance'),
    ]);
    notifyListeners();
  }

  Future<void> updateRoutineSettings({
    bool? classReminders,
    bool? attendanceCheckIn,
    bool? endPendingReminder,
    bool? endClassActions,
    bool? streak,
  }) async {
    if (classReminders != null) classRemindersEnabled = classReminders;
    if (attendanceCheckIn != null) attendanceCheckInEnabled = attendanceCheckIn;
    if (endPendingReminder != null) endPendingReminderEnabled = endPendingReminder;
    if (endClassActions != null) endClassActionsEnabled = endClassActions;
    if (streak != null) streakEnabled = streak;
    await Future.wait([
      _db.setSetting('class_reminders', '$classRemindersEnabled'),
      _db.setSetting('attendance_checkin', '$attendanceCheckInEnabled'),
      _db.setSetting('end_pending_reminder', '$endPendingReminderEnabled'),
      _db.setSetting('end_class_actions', '$endClassActionsEnabled'),
      _db.setSetting('attendance_streak', '$streakEnabled'),
    ]);
    if (classRemindersEnabled || attendanceCheckInEnabled || endPendingReminderEnabled || endClassActionsEnabled) {
      await notifications.requestPermission();
    }
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    isDark = !isDark;
    notifyListeners();
    await _db.setSetting('dark_mode', '$isDark');
  }

  void setIndex(int index) {
    final next = index.clamp(0, 4).toInt();
    if (currentIndex == next) return;
    currentIndex = next;
    notifyListeners();
  }

  void setKanbanMode(bool value) {
    if (kanbanMode == value) return;
    kanbanMode = value;
    notifyListeners();
  }

  Subject? subjectById(int? id) {
    if (id == null) return null;
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  ScheduleEntry? scheduleById(int? id) {
    if (id == null) return null;
    for (final s in schedules) {
      if (s.id == id) return s;
    }
    return null;
  }

  ClassSession? sessionById(int? id) {
    if (id == null) return null;
    for (final s in classSessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  AcademicTask? _taskById(int? id) {
    if (id == null) return null;
    for (final item in tasks) {
      if (item.id == id) return item;
    }
    return null;
  }

  AcademicNote? _noteById(int? id) {
    if (id == null) return null;
    for (final item in notes) {
      if (item.id == id) return item;
    }
    return null;
  }

  MaterialResource? _materialById(int? id) {
    if (id == null) return null;
    for (final item in materials) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<T> _runCreateOnce<T>(String key, Future<T> Function() action) async {
    final existing = _pendingCreates[key];
    if (existing != null) return await existing as T;
    final future = action();
    _pendingCreates[key] = future;
    try {
      return await future;
    } finally {
      if (identical(_pendingCreates[key], future)) _pendingCreates.remove(key);
    }
  }

  String subjectName(int? id) => subjectById(id)?.name ?? 'Sem matéria';
  List<AcademicTask> tasksForSubject(int id) => tasks.where((e) => e.subjectId == id).toList();
  List<Grade> gradesForSubject(int id) => grades.where((e) => e.subjectId == id).toList();
  List<ScheduleEntry> schedulesForSubject(int id) => schedules.where((e) => e.subjectId == id).toList();
  List<ClassSession> sessionsForSubject(int id) => classSessions.where((e) => e.subjectId == id).toList();
  List<AcademicNote> notesForSubject(int id) => notes.where((e) => e.subjectId == id).toList();
  List<MaterialResource> materialsForSubject(int id) => materials.where((e) => e.subjectId == id).toList();
  List<AcademicNote> notesForSession(int id) => notes.where((e) => e.sessionId == id).toList();
  List<MaterialResource> materialsForSession(int id) => materials.where((e) => e.sessionId == id).toList();
  List<AcademicTask> tasksForSession(int id) => tasks.where((e) => e.sessionId == id).toList();

  double? averageForSubject(int id) {
    final items = gradesForSubject(id);
    if (items.isEmpty) return null;
    final weight = items.fold<double>(0, (a, b) => a + b.weight);
    if (weight <= 0) return null;
    return items.fold<double>(0, (a, b) => a + b.value * b.weight) / weight;
  }

  double? get overallAverage {
    final values = subjects.where((s) => s.id != null).map((s) => averageForSubject(s.id!)).whereType<double>().toList();
    return values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
  }

  double attendanceForSubject(Subject subject) => subject.attendance;

  double? get averageAttendance {
    final withHistory = subjects.where((subject) => subject.totalClasses > 0).toList();
    if (withHistory.isEmpty) return null;
    return withHistory.fold<double>(0, (a, b) => a + b.attendance) / withHistory.length;
  }

  double attendanceTarget(Subject subject) => subject.minAttendance ?? minAttendance;
  int completedClassCount(Subject subject) => subject.totalClasses;
  int absenceCount(Subject subject) => subject.absences;

  bool isSubjectAtRisk(Subject s) {
    final avg = s.id == null ? null : averageForSubject(s.id!);
    return (avg != null && avg < minGrade) ||
        (s.totalClasses > 0 && s.attendance < attendanceTarget(s)) ||
        remainingAbsences(s) <= 1;
  }

  int maxAbsences(Subject s) {
    final planned = s.plannedClasses;
    if (planned <= 0) return -1;
    return (planned * (1 - attendanceTarget(s) / 100)).floor();
  }

  int remainingAbsences(Subject s) {
    final max = maxAbsences(s);
    return max < 0 ? 9999 : (max - s.absences).clamp(0, 9999).toInt();
  }

  double simulatedAttendance(Subject subject, int additionalAbsences) {
    final misses = additionalAbsences.clamp(0, 9999).toInt();
    final currentTotal = subject.totalClasses;
    final currentMisses = subject.absences;
    final futureTotal = currentTotal + misses;
    if (futureTotal <= 0) return 100;
    return ((futureTotal - currentMisses - misses).clamp(0, futureTotal) / futureTotal) * 100;
  }

  String attendanceRiskLabel(Subject subject) {
    final remaining = remainingAbsences(subject);
    if ((subject.totalClasses > 0 && subject.attendance < attendanceTarget(subject)) || remaining == 0) return 'LIMITE';
    if (remaining == 1) return 'RISCO';
    if (remaining <= 3) return 'ATENÇÃO';
    return 'SEGURO';
  }

  double? requiredNextGrade(int subjectId, {double futureWeight = 1}) {
    final items = gradesForSubject(subjectId);
    if (futureWeight <= 0) return null;
    final currentWeight = items.fold<double>(0, (a, b) => a + b.weight);
    final points = items.fold<double>(0, (a, b) => a + b.value * b.weight);
    return (minGrade * (currentWeight + futureWeight) - points) / futureWeight;
  }

  int get pendingCount => tasks.where((e) => e.status != TaskStatus.done).length;
  int get completedCount => tasks.where((e) => e.status == TaskStatus.done).length;

  List<AcademicTask> get dueToday {
    final n = DateTime.now();
    return tasks.where((t) => t.status != TaskStatus.done && _sameDay(t.dueDate, n)).toList();
  }

  List<ScheduleEntry> get classesToday =>
      (schedules.where((s) => s.day == DateTime.now().weekday).toList()..sort((a, b) => a.start.compareTo(b.start)));

  List<ClassSession> sessionsForDate(DateTime date) =>
      (classSessions.where((s) => _sameDay(s.date, date)).toList()..sort((a, b) => a.start.compareTo(b.start)));

  List<ClassSession> get sessionsToday => sessionsForDate(DateTime.now());

  ClassSession? get currentSession {
    final now = DateTime.now();
    for (final s in sessionsToday) {
      if (s.status != AttendanceStatus.cancelled && !now.isBefore(s.startsAt) && now.isBefore(s.endsAt)) return s;
    }
    return null;
  }

  ClassSession? get nextSession {
    final now = DateTime.now();
    final future = classSessions.where((s) => s.status != AttendanceStatus.cancelled && s.startsAt.isAfter(now)).toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return future.isEmpty ? null : future.first;
  }

  List<ClassSession> get pendingAttendance {
    final now = DateTime.now();
    return classSessions.where((s) => s.status == AttendanceStatus.pending && !s.startsAt.isAfter(now)).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
  }

  int get attendanceStreak {
    if (!streakEnabled) return 0;
    final resolved = classSessions.where((s) => s.status == AttendanceStatus.present || s.status == AttendanceStatus.absent).toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    var streak = 0;
    for (final s in resolved) {
      if (s.status == AttendanceStatus.absent) break;
      if (s.status == AttendanceStatus.present) streak++;
    }
    return streak;
  }

  Map<String, int> get weeklyAttendanceSummary {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final sundayEnd = monday.add(const Duration(days: 7));
    final week = classSessions.where((s) =>
        !s.date.isBefore(monday) &&
        s.date.isBefore(sundayEnd) &&
        s.status != AttendanceStatus.cancelled &&
        !s.startsAt.isAfter(now)).toList();
    return {
      'classes': week.fold<int>(0, (v, s) => v + s.classCount),
      'present': week.where((s) => s.status == AttendanceStatus.present).fold<int>(0, (v, s) => v + s.classCount),
      'absent': week.where((s) => s.status == AttendanceStatus.absent).fold<int>(0, (v, s) => v + s.classCount),
      'pending': week.where((s) => s.status == AttendanceStatus.pending).fold<int>(0, (v, s) => v + s.classCount),
    };
  }

  double get taskCompletionRate {
    if (tasks.isEmpty) return 100;
    final done = tasks.where((t) => t.status == TaskStatus.done).length;
    return done / tasks.length * 100;
  }

  double? get onTimeTaskRate {
    final measured = tasks.where((task) => task.status == TaskStatus.done && task.completedAt != null).toList();
    if (measured.isEmpty) return null;
    final onTime = measured.where((task) {
      final due = task.dueDate;
      final hasExplicitTime = due.hour != 0 || due.minute != 0 || due.second != 0 || due.millisecond != 0;
      final deadline = hasExplicitTime
          ? due
          : DateTime(due.year, due.month, due.day, 23, 59, 59, 999);
      return !task.completedAt!.isAfter(deadline);
    }).length;
    return onTime / measured.length * 100;
  }

  Future<Subject> saveSubject(Subject item, {bool preserveRoutineFields = true}) async {
    final existing = subjectById(item.id);
    if (existing != null) {
      final resolved = sessionsForSubject(existing.id!).where(
        (s) => s.status == AttendanceStatus.present || s.status == AttendanceStatus.absent,
      );
      final sessionTotal = resolved.fold<int>(0, (v, s) => v + s.classCount);
      final sessionAbsences = resolved
          .where((s) => s.status == AttendanceStatus.absent)
          .fold<int>(0, (v, s) => v + s.classCount);
      item = item.copyWith(
        totalClasses: (item.totalClasses - sessionTotal).clamp(0, 9999).toInt(),
        absences: (item.absences - sessionAbsences).clamp(0, 9999).toInt(),
        plannedClasses: preserveRoutineFields && item.plannedClasses == 0 && existing.plannedClasses > 0
            ? existing.plannedClasses
            : item.plannedClasses,
        minAttendance: preserveRoutineFields ? item.minAttendance ?? existing.minAttendance : item.minAttendance,
      );
    }
    final saved = item.id == null
        ? await _runCreateOnce('subject:${item.toMap()}', () => _db.saveSubject(item))
        : await _db.saveSubject(item);
    final rawSubjects = await _db.getSubjects();
    _captureSubjectBaselines(rawSubjects);
    subjects = rawSubjects;
    _projectAttendanceIntoSubjects();
    notifyListeners();
    return subjectById(saved.id) ?? saved;
  }

  Future<void> setSubjectAttendancePlan(Subject subject, {required int plannedClasses, required double? target}) async {
    await saveSubject(
      subject.copyWith(
        plannedClasses: plannedClasses.clamp(0, 9999).toInt(),
        minAttendance: target,
        clearMinAttendance: target == null,
      ),
      preserveRoutineFields: false,
    );
  }

  Future<void> setSubjectAttendanceTarget(Subject subject, double? value) async {
    await setSubjectAttendancePlan(subject, plannedClasses: subject.plannedClasses, target: value);
  }

  Future<void> deleteSubject(Subject item) async {
    if (item.id == null) return;
    await _db.deleteSubject(item.id!);
    await reloadAll();
    await _rescheduleNotifications();
  }

  Future<AcademicTask> saveTask(
    AcademicTask item, {
    bool reload = true,
    bool scheduleNotification = true,
    bool notify = true,
  }) async {
    final createKey = item.id == null
        ? 'task:${item.title}|${item.subjectId}|${item.dueDate.toIso8601String()}|${item.priority.index}|${item.status.index}|${item.kind.index}|${item.reminderEnabled}|${item.description}|${item.checklist.join('\u001F')}|${item.sessionId}'
        : null;
    final previous = _taskById(item.id);
    if (item.id != null && item.sessionId == null && previous?.sessionId != null) {
      item = item.copyWith(sessionId: previous!.sessionId);
    }
    if (item.status == TaskStatus.done && item.completedAt == null && previous?.status != TaskStatus.done) {
      item = item.copyWith(completedAt: DateTime.now());
    } else if (item.status != TaskStatus.done && item.completedAt != null) {
      item = item.copyWith(clearCompletedAt: true);
    }
    final saved = item.id == null
        ? await _runCreateOnce(createKey!, () => _db.saveTask(item))
        : await _db.saveTask(item);
    if (reload) tasks = await _db.getTasks();
    if (scheduleNotification) await notifications.scheduleTask(saved, subjectName(saved.subjectId));
    if (notify) notifyListeners();
    return saved;
  }

  Future<void> refreshTasksAfterBatch({bool rescheduleNotifications = true}) async {
    tasks = await _db.getTasks();
    if (rescheduleNotifications) await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> deleteTask(AcademicTask item) async {
    if (item.id == null) return;
    await notifications.cancelTask(item.id!);
    await _db.deleteTask(item.id!);
    tasks = await _db.getTasks();
    notifyListeners();
  }

  Future<void> moveTask(AcademicTask item, TaskStatus status) async => saveTask(item.copyWith(status: status));

  Future<void> toggleTaskStep(AcademicTask item, int step) async {
    final latest = _taskById(item.id) ?? item;
    if (step < 0 || step >= latest.checklist.length) return;
    final completed = [...latest.completedSteps];
    completed.contains(step) ? completed.remove(step) : completed.add(step);
    completed.sort();
    await saveTask(latest.copyWith(completedSteps: completed));
  }

  Future<Grade> saveGrade(Grade item) async {
    final v = item.id == null
        ? await _runCreateOnce('grade:${item.toMap()}', () => _db.saveGrade(item))
        : await _db.saveGrade(item);
    grades = await _db.getGrades();
    notifyListeners();
    return v;
  }

  Future<void> deleteGrade(Grade item) async {
    if (item.id == null) return;
    await _db.deleteGrade(item.id!);
    grades = await _db.getGrades();
    notifyListeners();
  }

  Future<ScheduleEntry> saveSchedule(ScheduleEntry item) async {
    _validateSchedule(item.day, item.start, item.end);
    if (item.id != null) await _db.deleteFutureSessionsForSchedule(item.id!, DateTime.now());
    final v = item.id == null
        ? await _runCreateOnce('schedule:${item.toMap()}', () => _db.saveSchedule(item))
        : await _db.saveSchedule(item);
    schedules = await _db.getSchedules();
    classSessions = await _db.getClassSessions();
    await ensureRoutineSessions(notify: false);
    if (classRemindersEnabled || attendanceCheckInEnabled || endPendingReminderEnabled || endClassActionsEnabled) {
      await notifications.requestPermission();
    }
    await _rescheduleNotifications();
    notifyListeners();
    return v;
  }

  Future<void> updateScheduleRoutine(ScheduleEntry item, {required int classCount, required int reminderMinutes}) async {
    await saveSchedule(
      item.copyWith(
        classCount: classCount.clamp(1, 8).toInt(),
        reminderMinutes: reminderMinutes.clamp(0, 120).toInt(),
      ),
    );
  }

  Future<void> deleteSchedule(ScheduleEntry item) async {
    if (item.id == null) return;
    await _db.deleteFutureSessionsForSchedule(item.id!, DateTime(2000));
    await _db.deleteSchedule(item.id!);
    schedules = await _db.getSchedules();
    classSessions = await _db.getClassSessions();
    tasks = await _db.getTasks();
    notes = await _db.getNotes();
    materials = await _db.getMaterials();
    _projectAttendanceIntoSubjects();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> ensureRoutineSessions({bool notify = true}) async {
    if (schedules.isEmpty) {
      classSessions = await _db.getClassSessions();
      _projectAttendanceIntoSubjects();
      if (notify) notifyListeners();
      return;
    }
    classSessions = await _db.getClassSessions();
    calendarEvents = await _db.getCalendarEvents();
    final existing = <String>{
      for (final s in classSessions)
        if (s.scheduleId != null) '${s.scheduleId}:${_dateKey(s.date)}',
    };
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final end = start.add(const Duration(days: 61));
    final schedulesByDay = <int, List<ScheduleEntry>>{};
    for (final schedule in schedules) {
      (schedulesByDay[schedule.day] ??= []).add(schedule);
    }
    for (var date = start; !date.isAfter(end); date = date.add(const Duration(days: 1))) {
      for (final schedule in schedulesByDay[date.weekday] ?? const <ScheduleEntry>[]) {
        if (schedule.id == null || existing.contains('${schedule.id}:${_dateKey(date)}')) continue;
        if (_classBlocked(date, schedule.subjectId)) continue;
        final saved = await _db.saveClassSession(
          ClassSession(
            subjectId: schedule.subjectId,
            scheduleId: schedule.id,
            date: date,
            start: schedule.start,
            end: schedule.end,
            room: schedule.room,
            classCount: schedule.classCount,
            createdAt: DateTime.now(),
          ),
        );
        if (saved.id != null) existing.add('${schedule.id}:${_dateKey(date)}');
      }
    }
    classSessions = await _db.getClassSessions();
    _projectAttendanceIntoSubjects();
    if (notify) notifyListeners();
  }

  bool _classBlocked(DateTime date, int subjectId) {
    return calendarEvents.any((e) => e.blocksClasses && _sameDay(e.date, date) && (e.subjectId == null || e.subjectId == subjectId));
  }

  Future<ClassSession> saveClassSession(ClassSession item) async {
    _validateSchedule(item.date.weekday, item.start, item.end);
    final createKey = 'session:${item.subjectId}|${item.scheduleId}|${_dateKey(item.date)}|${item.start}|${item.end}|${item.room}|${item.classCount}|${item.kind.index}|${item.makeupForSessionId}';
    final saved = item.id == null
        ? await _runCreateOnce(createKey, () => _db.saveClassSession(item))
        : await _db.saveClassSession(item);
    classSessions = await _db.getClassSessions();
    _projectAttendanceIntoSubjects();
    await _rescheduleNotifications();
    notifyListeners();
    return saved;
  }

  Future<void> markAttendance(ClassSession session, AttendanceStatus status) async {
    if (session.id == null) return;
    final current = sessionById(session.id) ?? session;
    final updated = current.copyWith(status: status);
    await _db.saveClassSession(updated);
    await notifications.cancelClassSession(session.id!);
    classSessions = await _db.getClassSessions();
    _projectAttendanceIntoSubjects();

    if (status != AttendanceStatus.cancelled && endClassActionsEnabled && updated.endsAt.isAfter(DateTime.now())) {
      await notifications.scheduleClassSession(
        updated,
        subjectName(updated.subjectId),
        reminderMinutes: 0,
        classRemindersEnabled: false,
        attendanceCheckInEnabled: false,
        endPendingReminderEnabled: false,
        endClassActionsEnabled: true,
      );
    }
    notifyListeners();
  }

  Future<void> deleteClassSession(ClassSession session) async {
    if (session.id == null) return;
    await notifications.cancelClassSession(session.id!);
    await _db.deleteClassSession(session.id!);
    classSessions = await _db.getClassSessions();
    tasks = await _db.getTasks();
    notes = await _db.getNotes();
    materials = await _db.getMaterials();
    _projectAttendanceIntoSubjects();
    notifyListeners();
  }

  Future<AcademicCalendarEvent> saveCalendarEvent(AcademicCalendarEvent item) async {
    final saved = item.id == null
        ? await _runCreateOnce('calendar:${item.toMap()}', () => _db.saveCalendarEvent(item))
        : await _db.saveCalendarEvent(item);
    calendarEvents = await _db.getCalendarEvents();
    var detachedLinks = false;
    if (saved.blocksClasses) {
      final impacted = classSessions.where(
        (s) => s.kind == ClassSessionKind.regular &&
            s.status == AttendanceStatus.pending &&
            _sameDay(s.date, saved.date) &&
            (saved.subjectId == null || saved.subjectId == s.subjectId),
      ).toList();
      for (final s in impacted) {
        if (s.id == null) continue;
        await notifications.cancelClassSession(s.id!);
        await _db.deleteClassSession(s.id!);
        detachedLinks = true;
      }
    }
    if (detachedLinks) {
      tasks = await _db.getTasks();
      notes = await _db.getNotes();
      materials = await _db.getMaterials();
    }
    await ensureRoutineSessions(notify: false);
    await _rescheduleNotifications();
    notifyListeners();
    return saved;
  }

  Future<void> deleteCalendarEvent(AcademicCalendarEvent item) async {
    if (item.id == null) return;
    await _db.deleteCalendarEvent(item.id!);
    calendarEvents = await _db.getCalendarEvents();
    await ensureRoutineSessions(notify: false);
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<AcademicNote> saveNote(AcademicNote item) async {
    final previous = _noteById(item.id);
    if (item.id != null && item.sessionId == null && previous?.sessionId != null) {
      item = AcademicNote(
        id: item.id,
        subjectId: item.subjectId,
        title: item.title,
        content: item.content,
        link: item.link,
        tags: item.tags,
        pinned: item.pinned,
        createdAt: item.createdAt,
        sessionId: previous!.sessionId,
      );
    }
    final createKey = 'note:${item.subjectId}|${item.title}|${item.content}|${item.link}|${item.tags}|${item.pinned}|${item.sessionId}';
    final v = item.id == null
        ? await _runCreateOnce(createKey, () => _db.saveNote(item))
        : await _db.saveNote(item);
    notes = await _db.getNotes();
    notifyListeners();
    return v;
  }

  Future<void> deleteNote(AcademicNote item) async {
    if (item.id == null) return;
    await _db.deleteNote(item.id!);
    notes = await _db.getNotes();
    notifyListeners();
  }

  Future<MaterialResource> saveMaterial(MaterialResource item) async {
    final previous = _materialById(item.id);
    if (item.id != null && item.sessionId == null && previous?.sessionId != null) {
      item = MaterialResource(
        id: item.id,
        subjectId: item.subjectId,
        title: item.title,
        url: item.url,
        description: item.description,
        kind: item.kind,
        createdAt: item.createdAt,
        sessionId: previous!.sessionId,
      );
    }
    final createKey = 'material:${item.subjectId}|${item.title}|${item.url}|${item.description}|${item.kind.index}|${item.sessionId}';
    final v = item.id == null
        ? await _runCreateOnce(createKey, () => _db.saveMaterial(item))
        : await _db.saveMaterial(item);
    materials = await _db.getMaterials();
    notifyListeners();
    return v;
  }

  Future<void> deleteMaterial(MaterialResource item) async {
    if (item.id == null) return;
    await _db.deleteMaterial(item.id!);
    materials = await _db.getMaterials();
    notifyListeners();
  }

  Future<void> _handleRoutineAction(String actionId, String payload) async {
    final id = int.tryParse(payload.split(':').last);
    final session = sessionById(id);
    if (session == null) return;
    final status = switch (actionId) {
      'routine_present' => AttendanceStatus.present,
      'routine_absent' => AttendanceStatus.absent,
      'routine_cancelled' => AttendanceStatus.cancelled,
      _ => AttendanceStatus.pending,
    };
    if (status != AttendanceStatus.pending) await markAttendance(session, status);
    highlightedSessionId = session.id;
    currentIndex = 4;
    notifyListeners();
  }

  Future<void> _handleNotificationTap(String payload) async {
    if (payload.startsWith('session:')) {
      highlightedSessionId = int.tryParse(payload.split(':').last);
      currentIndex = 4;
      notifyListeners();
    }
  }

  int _reminderMinutesForSchedule(int? scheduleId) => scheduleById(scheduleId)?.reminderMinutes ?? 10;

  Future<void> _rescheduleNotifications() async {
    await notifications.rescheduleEverything(
      tasks: tasks,
      sessions: classSessions,
      subjectName: subjectName,
      reminderMinutesForSchedule: _reminderMinutesForSchedule,
      classRemindersEnabled: classRemindersEnabled,
      attendanceCheckInEnabled: attendanceCheckInEnabled,
      endPendingReminderEnabled: endPendingReminderEnabled,
      endClassActionsEnabled: endClassActionsEnabled,
    );
  }

  Future<void> clearAcademicData() async {
    await _db.clearAcademicData();
    await reloadAll(notify: false);
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> resetEverything() async {
    await _db.resetEverything();
    userName = '';
    course = '';
    period = '';
    semester = '';
    isDark = true;
    minGrade = 6;
    minAttendance = 75;
    currentIndex = 0;
    classRemindersEnabled = true;
    attendanceCheckInEnabled = true;
    endPendingReminderEnabled = true;
    endClassActionsEnabled = false;
    streakEnabled = true;
    highlightedSessionId = null;
    await reloadAll(notify: false);
    await _rescheduleNotifications();
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key, required AppState notifier, required super.child}) : super(notifier: notifier);
  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope não encontrado');
    return scope!.notifier!;
  }
}

void _validateSchedule(int day, String start, String end) {
  if (day < 1 || day > 7) throw ArgumentError('Dia da semana inválido.');
  final startMinutes = _timeMinutes(start);
  final endMinutes = _timeMinutes(end);
  if (startMinutes == null || endMinutes == null || endMinutes <= startMinutes) {
    throw ArgumentError('O horário final deve ser posterior ao horário inicial.');
  }
}

int? _timeMinutes(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return hour * 60 + minute;
}

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
