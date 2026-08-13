import 'package:flutter/material.dart';
import '../data/demo_data.dart';
import '../models/models.dart';

class AppState extends ChangeNotifier {
  bool isDark = true;
  int currentIndex = 0;
  bool kanbanMode = true;
  final List<AcademicTask> tasks = initialTasks
      .map((e) => AcademicTask(
            id: e.id,
            title: e.title,
            subject: e.subject,
            dueDate: e.dueDate,
            priority: e.priority,
            status: e.status,
            description: e.description,
          ))
      .toList();

  void toggleTheme() {
    isDark = !isDark;
    notifyListeners();
  }

  void setIndex(int index) {
    currentIndex = index;
    notifyListeners();
  }

  void setKanbanMode(bool value) {
    kanbanMode = value;
    notifyListeners();
  }

  void moveTask(AcademicTask task, TaskStatus status) {
    task.status = status;
    notifyListeners();
  }

  void addTask(AcademicTask task) {
    tasks.add(task);
    notifyListeners();
  }

  int get pendingCount => tasks.where((t) => t.status != TaskStatus.done).length;
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
