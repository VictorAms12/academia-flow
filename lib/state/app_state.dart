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

  List<Subject> subjects = [];
  List<AcademicTask> tasks = [];
  List<Grade> grades = [];
  List<ScheduleEntry> schedules = [];
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
    await reloadAll(notify: false);
    await notifications.initialize();
    await notifications.rescheduleAll(tasks, subjectName);
  }

  Future<void> reloadAll({bool notify = true}) async {
    subjects = await _db.getSubjects();
    tasks = await _db.getTasks();
    grades = await _db.getGrades();
    schedules = await _db.getSchedules();
    notes = await _db.getNotes();
    materials = await _db.getMaterials();
    if (notify) notifyListeners();
  }

  Future<void> saveProfile({required String name, required String courseName, required String periodName, required String semesterName}) async {
    userName = name.trim(); course = courseName.trim(); period = periodName.trim(); semester = semesterName.trim();
    await Future.wait([
      _db.setSetting('user_name', userName), _db.setSetting('course', course),
      _db.setSetting('period', period), _db.setSetting('semester', semester),
    ]);
    notifyListeners();
  }

  Future<void> updateThresholds(double grade, double attendance) async {
    minGrade = grade; minAttendance = attendance;
    await Future.wait([_db.setSetting('min_grade', '$grade'), _db.setSetting('min_attendance', '$attendance')]);
    notifyListeners();
  }

  Future<void> toggleTheme() async { isDark = !isDark; notifyListeners(); await _db.setSetting('dark_mode', '$isDark'); }
  void setIndex(int index) { currentIndex = index; notifyListeners(); }
  void setKanbanMode(bool value) { kanbanMode = value; notifyListeners(); }

  Subject? subjectById(int? id) { if (id == null) return null; for (final s in subjects) { if (s.id == id) return s; } return null; }
  String subjectName(int? id) => subjectById(id)?.name ?? 'Sem matéria';
  List<AcademicTask> tasksForSubject(int id) => tasks.where((e) => e.subjectId == id).toList();
  List<Grade> gradesForSubject(int id) => grades.where((e) => e.subjectId == id).toList();
  List<ScheduleEntry> schedulesForSubject(int id) => schedules.where((e) => e.subjectId == id).toList();
  List<AcademicNote> notesForSubject(int id) => notes.where((e) => e.subjectId == id).toList();
  List<MaterialResource> materialsForSubject(int id) => materials.where((e) => e.subjectId == id).toList();

  double? averageForSubject(int id) {
    final items = gradesForSubject(id); if (items.isEmpty) return null;
    final weight = items.fold<double>(0, (a, b) => a + b.weight); if (weight <= 0) return null;
    return items.fold<double>(0, (a, b) => a + b.value * b.weight) / weight;
  }

  double? get overallAverage {
    final values = subjects.where((s) => s.id != null).map((s) => averageForSubject(s.id!)).whereType<double>().toList();
    return values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
  }

  double? get averageAttendance => subjects.isEmpty ? null : subjects.fold<double>(0, (a, b) => a + b.attendance) / subjects.length;
  bool isSubjectAtRisk(Subject s) { final avg = s.id == null ? null : averageForSubject(s.id!); return (avg != null && avg < minGrade) || s.attendance < minAttendance || remainingAbsences(s) <= 1; }

  int maxAbsences(Subject s) => s.plannedClasses <= 0 ? -1 : (s.plannedClasses * (1 - minAttendance / 100)).floor();
  int remainingAbsences(Subject s) { final max = maxAbsences(s); return max < 0 ? 9999 : (max - s.absences).clamp(0, 9999).toInt(); }

  double? requiredNextGrade(int subjectId, {double futureWeight = 1}) {
    final items = gradesForSubject(subjectId); if (futureWeight <= 0) return null;
    final currentWeight = items.fold<double>(0, (a, b) => a + b.weight);
    final points = items.fold<double>(0, (a, b) => a + b.value * b.weight);
    return (minGrade * (currentWeight + futureWeight) - points) / futureWeight;
  }

  int get pendingCount => tasks.where((e) => e.status != TaskStatus.done).length;
  int get completedCount => tasks.where((e) => e.status == TaskStatus.done).length;
  List<AcademicTask> get dueToday { final n = DateTime.now(); return tasks.where((t) => t.status != TaskStatus.done && t.dueDate.year == n.year && t.dueDate.month == n.month && t.dueDate.day == n.day).toList(); }
  List<ScheduleEntry> get classesToday => (schedules.where((s) => s.day == DateTime.now().weekday).toList()..sort((a, b) => a.start.compareTo(b.start)));

  Future<Subject> saveSubject(Subject item) async { final saved = await _db.saveSubject(item); subjects = await _db.getSubjects(); notifyListeners(); return saved; }
  Future<void> deleteSubject(Subject item) async { if (item.id == null) return; await _db.deleteSubject(item.id!); await reloadAll(); await notifications.rescheduleAll(tasks, subjectName); }

  Future<AcademicTask> saveTask(AcademicTask item) async { final saved = await _db.saveTask(item); tasks = await _db.getTasks(); await notifications.scheduleTask(saved, subjectName(saved.subjectId)); notifyListeners(); return saved; }
  Future<void> deleteTask(AcademicTask item) async { if (item.id == null) return; await notifications.cancelTask(item.id!); await _db.deleteTask(item.id!); tasks = await _db.getTasks(); notifyListeners(); }
  Future<void> moveTask(AcademicTask item, TaskStatus status) async {
    await saveTask(item.copyWith(status: status));
  }
  Future<void> toggleTaskStep(AcademicTask item, int step) async { final c = [...item.completedSteps]; c.contains(step) ? c.remove(step) : c.add(step); await saveTask(item.copyWith(completedSteps: c)); }

  Future<Grade> saveGrade(Grade item) async { final v = await _db.saveGrade(item); grades = await _db.getGrades(); notifyListeners(); return v; }
  Future<void> deleteGrade(Grade item) async { if (item.id == null) return; await _db.deleteGrade(item.id!); grades = await _db.getGrades(); notifyListeners(); }
  Future<ScheduleEntry> saveSchedule(ScheduleEntry item) async { final v = await _db.saveSchedule(item); schedules = await _db.getSchedules(); notifyListeners(); return v; }
  Future<void> deleteSchedule(ScheduleEntry item) async { if (item.id == null) return; await _db.deleteSchedule(item.id!); schedules = await _db.getSchedules(); notifyListeners(); }
  Future<AcademicNote> saveNote(AcademicNote item) async { final v = await _db.saveNote(item); notes = await _db.getNotes(); notifyListeners(); return v; }
  Future<void> deleteNote(AcademicNote item) async { if (item.id == null) return; await _db.deleteNote(item.id!); notes = await _db.getNotes(); notifyListeners(); }
  Future<MaterialResource> saveMaterial(MaterialResource item) async { final v = await _db.saveMaterial(item); materials = await _db.getMaterials(); notifyListeners(); return v; }
  Future<void> deleteMaterial(MaterialResource item) async { if (item.id == null) return; await _db.deleteMaterial(item.id!); materials = await _db.getMaterials(); notifyListeners(); }

  Future<void> clearAcademicData() async { await notifications.rescheduleAll([], subjectName); await _db.clearAcademicData(); await reloadAll(); }
  Future<void> resetEverything() async {
    await notifications.rescheduleAll([], subjectName); await _db.resetEverything();
    userName = ''; course = ''; period = ''; semester = ''; isDark = true; minGrade = 6; minAttendance = 75; currentIndex = 0;
    await reloadAll(notify: false); notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({super.key, required AppState notifier, required super.child}) : super(notifier: notifier);
  static AppState of(BuildContext context) { final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>(); assert(scope != null, 'AppStateScope não encontrado'); return scope!.notifier!; }
}
