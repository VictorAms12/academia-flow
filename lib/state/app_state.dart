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

  bool get onboardingComplete => userName.trim().isNotEmpty && course.trim().isNotEmpty;

  Future<void> initialize() async {
    await _db.database;
    userName = await _db.getSetting('user_name') ?? '';
    course = await _db.getSetting('course') ?? '';
    period = await _db.getSetting('period') ?? '';
    semester = await _db.getSetting('semester') ?? '';
    isDark = (await _db.getSetting('dark_mode') ?? 'true') == 'true';
    minGrade = double.tryParse(await _db.getSetting('min_grade') ?? '') ?? 6.0;
    minAttendance = double.tryParse(await _db.getSetting('min_attendance') ?? '') ?? 75.0;
    classRemindersEnabled = (await _db.getSetting('class_reminders') ?? 'true') == 'true';
    attendanceCheckInEnabled = (await _db.getSetting('attendance_checkin') ?? 'true') == 'true';
    endPendingReminderEnabled = (await _db.getSetting('end_pending_reminder') ?? 'true') == 'true';
    endClassActionsEnabled = (await _db.getSetting('end_class_actions') ?? 'false') == 'true';
    streakEnabled = (await _db.getSetting('attendance_streak') ?? 'true') == 'true';

    await reloadAll(notify: false);
    await ensureRoutineSessions(notify: false);
    notifications.onRoutineAction = _handleRoutineAction;
    notifications.onNotificationTap = _handleNotificationTap;
    await notifications.initialize();
    await _rescheduleNotifications();
  }

  Future<void> reloadAll({bool notify = true}) async {
    subjects = await _db.getSubjects();
    tasks = await _db.getTasks();
    grades = await _db.getGrades();
    schedules = await _db.getSchedules();
    classSessions = await _db.getClassSessions();
    calendarEvents = await _db.getCalendarEvents();
    notes = await _db.getNotes();
    materials = await _db.getMaterials();
    if (notify) notifyListeners();
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
    minGrade = grade;
    minAttendance = attendance;
    await Future.wait([
      _db.setSetting('min_grade', '$grade'),
      _db.setSetting('min_attendance', '$attendance'),
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
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    isDark = !isDark;
    notifyListeners();
    await _db.setSetting('dark_mode', '$isDark');
  }

  void setIndex(int index) {
    currentIndex = index;
    notifyListeners();
  }

  void setKanbanMode(bool value) {
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

  double attendanceForSubject(Subject subject) {
    if (subject.id == null) return subject.attendance;
    final resolved = sessionsForSubject(subject.id!).where((s) => s.status == AttendanceStatus.present || s.status == AttendanceStatus.absent).toList();
    if (resolved.isEmpty) return subject.attendance;
    final total = resolved.fold<int>(0, (v, s) => v + s.classCount);
    if (total <= 0) return 100;
    final misses = resolved.where((s) => s.status == AttendanceStatus.absent).fold<int>(0, (v, s) => v + s.classCount);
    return ((total - misses) / total) * 100;
  }

  double? get averageAttendance {
    if (subjects.isEmpty) return null;
    return subjects.fold<double>(0, (a, b) => a + attendanceForSubject(b)) / subjects.length;
  }

  double attendanceTarget(Subject subject) => subject.minAttendance ?? minAttendance;

  int completedClassCount(Subject subject) {
    if (subject.id == null) return subject.totalClasses;
    final resolved = sessionsForSubject(subject.id!).where((s) => s.status == AttendanceStatus.present || s.status == AttendanceStatus.absent).toList();
    if (resolved.isEmpty) return subject.totalClasses;
    return resolved.fold<int>(0, (v, s) => v + s.classCount);
  }

  int absenceCount(Subject subject) {
    if (subject.id == null) return subject.absences;
    final resolved = sessionsForSubject(subject.id!).where((s) => s.status == AttendanceStatus.absent).toList();
    if (sessionsForSubject(subject.id!).where((s) => s.status == AttendanceStatus.present || s.status == AttendanceStatus.absent).isEmpty) return subject.absences;
    return resolved.fold<int>(0, (v, s) => v + s.classCount);
  }

  bool isSubjectAtRisk(Subject s) {
    final avg = s.id == null ? null : averageForSubject(s.id!);
    return (avg != null && avg < minGrade) || attendanceForSubject(s) < attendanceTarget(s) || remainingAbsences(s) <= 1;
  }

  int maxAbsences(Subject s) {
    final planned = s.plannedClasses;
    if (planned <= 0) return -1;
    return (planned * (1 - attendanceTarget(s) / 100)).floor();
  }

  int remainingAbsences(Subject s) {
    final max = maxAbsences(s);
    return max < 0 ? 9999 : (max - absenceCount(s)).clamp(0, 9999).toInt();
  }

  double simulatedAttendance(Subject subject, int additionalAbsences) {
    final currentTotal = completedClassCount(subject);
    final currentMisses = absenceCount(subject);
    final futureTotal = currentTotal + additionalAbsences;
    if (futureTotal <= 0) return 100;
    return ((futureTotal - currentMisses - additionalAbsences).clamp(0, futureTotal) / futureTotal) * 100;
  }

  String attendanceRiskLabel(Subject subject) {
    final remaining = remainingAbsences(subject);
    final attendance = attendanceForSubject(subject);
    if (attendance < attendanceTarget(subject) || remaining == 0) return 'LIMITE';
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

  List<ScheduleEntry> get classesToday => (schedules.where((s) => s.day == DateTime.now().weekday).toList()..sort((a, b) => a.start.compareTo(b.start)));

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
    final week = classSessions.where((s) => !s.date.isBefore(monday) && s.date.isBefore(sundayEnd)).toList();
    return {
      'classes': week.where((s) => s.status != AttendanceStatus.cancelled).fold<int>(0, (v, s) => v + s.classCount),
      'present': week.where((s) => s.status == AttendanceStatus.present).fold<int>(0, (v, s) => v + s.classCount),
      'absent': week.where((s) => s.status == AttendanceStatus.absent).fold<int>(0, (v, s) => v + s.classCount),
      'pending': week.where((s) => s.status == AttendanceStatus.pending && !s.startsAt.isAfter(now)).fold<int>(0, (v, s) => v + s.classCount),
    };
  }

  double get onTimeTaskRate {
    if (tasks.isEmpty) return 100;
    final done = tasks.where((t) => t.status == TaskStatus.done).length;
    return done / tasks.length * 100;
  }

  Future<Subject> saveSubject(Subject item) async {
    final saved = await _db.saveSubject(item);
    subjects = await _db.getSubjects();
    notifyListeners();
    return saved;
  }

  Future<void> setSubjectAttendanceTarget(Subject subject, double? value) async {
    await saveSubject(subject.copyWith(minAttendance: value, clearMinAttendance: value == null));
  }

  Future<void> deleteSubject(Subject item) async {
    if (item.id == null) return;
    await _db.deleteSubject(item.id!);
    await reloadAll();
    await _rescheduleNotifications();
  }

  Future<AcademicTask> saveTask(AcademicTask item) async {
    final saved = await _db.saveTask(item);
    tasks = await _db.getTasks();
    await notifications.scheduleTask(saved, subjectName(saved.subjectId));
    notifyListeners();
    return saved;
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
    final c = [...item.completedSteps];
    c.contains(step) ? c.remove(step) : c.add(step);
    await saveTask(item.copyWith(completedSteps: c));
  }

  Future<Grade> saveGrade(Grade item) async {
    final v = await _db.saveGrade(item);
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
    if (item.id != null) await _db.deleteFutureSessionsForSchedule(item.id!, DateTime.now());
    final v = await _db.saveSchedule(item);
    schedules = await _db.getSchedules();
    await ensureRoutineSessions(notify: false);
    await _rescheduleNotifications();
    notifyListeners();
    return v;
  }

  Future<void> updateScheduleRoutine(ScheduleEntry item, {required int classCount, required int reminderMinutes}) async {
    await saveSchedule(item.copyWith(classCount: classCount.clamp(1, 8), reminderMinutes: reminderMinutes.clamp(0, 120)));
  }

  Future<void> deleteSchedule(ScheduleEntry item) async {
    if (item.id == null) return;
    await _db.deleteFutureSessionsForSchedule(item.id!, DateTime(2000));
    await _db.deleteSchedule(item.id!);
    schedules = await _db.getSchedules();
    classSessions = await _db.getClassSessions();
    await _rescheduleNotifications();
    notifyListeners();
  }

  Future<void> ensureRoutineSessions({bool notify = true}) async {
    if (schedules.isEmpty) {
      classSessions = await _db.getClassSessions();
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
    final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 14));
    final end = start.add(const Duration(days: 75));
    for (var date = start; !date.isAfter(end); date = date.add(const Duration(days: 1))) {
      for (final schedule in schedules.where((s) => s.day == date.weekday)) {
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
    if (notify) notifyListeners();
  }

  bool _classBlocked(DateTime date, int subjectId) {
    return calendarEvents.any((e) => e.blocksClasses && _sameDay(e.date, date) && (e.subjectId == null || e.subjectId == subjectId));
  }

  Future<ClassSession> saveClassSession(ClassSession item) async {
    final saved = await _db.saveClassSession(item);
    classSessions = await _db.getClassSessions();
    await _rescheduleNotifications();
    notifyListeners();
    return saved;
  }

  Future<void> markAttendance(ClassSession session, AttendanceStatus status) async {
    if (session.id == null) return;
    final updated = session.copyWith(status: status);
    await _db.saveClassSession(updated);
    await notifications.cancelClassSession(session.id!);
    classSessions = await _db.getClassSessions();
    notifyListeners();
  }

  Future<void> deleteClassSession(ClassSession session) async {
    if (session.id == null) return;
    await notifications.cancelClassSession(session.id!);
    await _db.deleteClassSession(session.id!);
    classSessions = await _db.getClassSessions();
    notifyListeners();
  }

  Future<AcademicCalendarEvent> saveCalendarEvent(AcademicCalendarEvent item) async {
    final saved = await _db.saveCalendarEvent(item);
    calendarEvents = await _db.getCalendarEvents();
    if (saved.blocksClasses) {
      final impacted = classSessions.where((s) => s.kind == ClassSessionKind.regular && s.status == AttendanceStatus.pending && _sameDay(s.date, saved.date) && (saved.subjectId == null || saved.subjectId == s.subjectId)).toList();
      for (final s in impacted) {
        if (s.id != null) await _db.deleteClassSession(s.id!);
      }
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
    final v = await _db.saveNote(item);
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
    final v = await _db.saveMaterial(item);
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

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
