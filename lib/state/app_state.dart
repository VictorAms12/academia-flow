import 'package:flutter/material.dart';
import '../data/app_database.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  final AppDatabase _db = AppDatabase.instance;

  bool isDark = true;
  int currentIndex = 0;
  bool kanbanMode = true;

  String userName = '';
  String course = '';
  String period = '';
  String semester = '';
  double minGrade = 6.0;
  double minAttendance = 75.0;

  List<Subject> subjects = [];
  List<AcademicTask> tasks = [];
  List<Grade> grades = [];
  List<ScheduleEntry> schedules = [];
  List<AcademicNote> notes = [];

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
    await reloadAll(notify: false);
  }

  Future<void> reloadAll({bool notify = true}) async {
    subjects = await _db.getSubjects();
    tasks = await _db.getTasks();
    grades = await _db.getGrades();
    schedules = await _db.getSchedules();
    notes = await _db.getNotes();
    if (notify) notifyListeners();
  }

  Future<void> saveProfile({
    required String name,
    required String courseName,
    required String periodName,
    required String semesterName,
  }) async {
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
      _db.setSetting('min_grade', grade.toString()),
      _db.setSetting('min_attendance', attendance.toString()),
    ]);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    isDark = !isDark;
    notifyListeners();
    await _db.setSetting('dark_mode', isDark.toString());
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
    for (final subject in subjects) {
      if (subject.id == id) return subject;
    }
    return null;
  }

  String subjectName(int? id) => subjectById(id)?.name ?? 'Sem matéria';

  List<AcademicTask> tasksForSubject(int subjectId) =>
      tasks.where((e) => e.subjectId == subjectId).toList();

  List<Grade> gradesForSubject(int subjectId) =>
      grades.where((e) => e.subjectId == subjectId).toList();

  List<ScheduleEntry> schedulesForSubject(int subjectId) =>
      schedules.where((e) => e.subjectId == subjectId).toList();

  List<AcademicNote> notesForSubject(int subjectId) =>
      notes.where((e) => e.subjectId == subjectId).toList();

  double? averageForSubject(int subjectId) {
    final items = gradesForSubject(subjectId);
    if (items.isEmpty) return null;
    final totalWeight = items.fold<double>(0, (sum, item) => sum + item.weight);
    if (totalWeight <= 0) return null;
    final weighted = items.fold<double>(0, (sum, item) => sum + item.value * item.weight);
    return weighted / totalWeight;
  }

  double? get overallAverage {
    final values = subjects
        .where((s) => s.id != null)
        .map((s) => averageForSubject(s.id!))
        .whereType<double>()
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double? get averageAttendance {
    if (subjects.isEmpty) return null;
    return subjects.fold<double>(0, (sum, s) => sum + s.attendance) / subjects.length;
  }

  bool isSubjectAtRisk(Subject subject) {
    final avg = subject.id == null ? null : averageForSubject(subject.id!);
    return (avg != null && avg < minGrade) || subject.attendance < minAttendance;
  }

  int get pendingCount => tasks.where((e) => e.status != TaskStatus.done).length;

  int get completedCount => tasks.where((e) => e.status == TaskStatus.done).length;

  Future<Subject> saveSubject(Subject subject) async {
    final saved = await _db.saveSubject(subject);
    subjects = await _db.getSubjects();
    notifyListeners();
    return saved;
  }

  Future<void> deleteSubject(Subject subject) async {
    if (subject.id == null) return;
    await _db.deleteSubject(subject.id!);
    await reloadAll();
  }

  Future<AcademicTask> saveTask(AcademicTask task) async {
    final saved = await _db.saveTask(task);
    tasks = await _db.getTasks();
    notifyListeners();
    return saved;
  }

  Future<void> deleteTask(AcademicTask task) async {
    if (task.id == null) return;
    await _db.deleteTask(task.id!);
    tasks = await _db.getTasks();
    notifyListeners();
  }

  Future<void> moveTask(AcademicTask task, TaskStatus status) async {
    await saveTask(task.copyWith(status: status));
  }

  Future<void> toggleTaskStep(AcademicTask task, int step) async {
    final completed = [...task.completedSteps];
    if (completed.contains(step)) {
      completed.remove(step);
    } else {
      completed.add(step);
    }
    await saveTask(task.copyWith(completedSteps: completed));
  }

  Future<Grade> saveGrade(Grade grade) async {
    final saved = await _db.saveGrade(grade);
    grades = await _db.getGrades();
    notifyListeners();
    return saved;
  }

  Future<void> deleteGrade(Grade grade) async {
    if (grade.id == null) return;
    await _db.deleteGrade(grade.id!);
    grades = await _db.getGrades();
    notifyListeners();
  }

  Future<ScheduleEntry> saveSchedule(ScheduleEntry entry) async {
    final saved = await _db.saveSchedule(entry);
    schedules = await _db.getSchedules();
    notifyListeners();
    return saved;
  }

  Future<void> deleteSchedule(ScheduleEntry entry) async {
    if (entry.id == null) return;
    await _db.deleteSchedule(entry.id!);
    schedules = await _db.getSchedules();
    notifyListeners();
  }

  Future<AcademicNote> saveNote(AcademicNote note) async {
    final saved = await _db.saveNote(note);
    notes = await _db.getNotes();
    notifyListeners();
    return saved;
  }

  Future<void> deleteNote(AcademicNote note) async {
    if (note.id == null) return;
    await _db.deleteNote(note.id!);
    notes = await _db.getNotes();
    notifyListeners();
  }

  Future<void> clearAcademicData() async {
    await _db.clearAcademicData();
    await reloadAll();
  }

  Future<void> resetEverything() async {
    await _db.resetEverything();
    userName = '';
    course = '';
    period = '';
    semester = '';
    isDark = true;
    minGrade = 6.0;
    minAttendance = 75.0;
    currentIndex = 0;
    await reloadAll(notify: false);
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope não encontrado');
    return scope!.notifier!;
  }
}
