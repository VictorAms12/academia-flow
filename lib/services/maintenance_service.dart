import 'dart:convert';

import '../data/app_database.dart';
import '../models/v26_models.dart';
import '../state/app_state.dart';
import '../state/v26_controller.dart';
import 'attachment_repository.dart';

class MaintenanceService {
  MaintenanceService._();

  static final MaintenanceService instance = MaintenanceService._();

  final AppDatabase _db = AppDatabase.instance;
  final AttachmentRepository _attachments = AttachmentRepository.instance;

  Future<void> afterAcademicClear(AppState state) async {
    await Future.wait([
      _db.setSetting('study_blocks_v26', '[]'),
      _db.setSetting('dismissed_insights_v26', '[]'),
    ]);
    final smart = V26Controller.instance;
    smart
      ..studyBlocks = []
      ..dismissedInsights = <String>{}
      ..bind(state)
      ..notifyListeners();
    await _attachments.initialize();
    await _attachments.pruneOrphanedFiles();
  }

  Future<void> afterFullReset(AppState state) async {
    final smart = V26Controller.instance;
    smart
      ..studyBlocks = []
      ..dismissedInsights = <String>{}
      ..bind(state)
      ..notifyListeners();
    await _attachments.initialize();
    await _attachments.pruneOrphanedFiles();
  }

  Future<void> reloadFromStorage(AppState state) async {
    final settings = await _db.getSettings();
    state.userName = settings['user_name'] ?? '';
    state.course = settings['course'] ?? '';
    state.period = settings['period'] ?? '';
    state.semester = settings['semester'] ?? '';
    state.isDark = (settings['dark_mode'] ?? 'true') == 'true';
    state.minGrade = double.tryParse(settings['min_grade'] ?? '') ?? 6.0;
    state.minAttendance = double.tryParse(settings['min_attendance'] ?? '') ?? 75.0;
    state.classRemindersEnabled = (settings['class_reminders'] ?? 'true') == 'true';
    state.attendanceCheckInEnabled = (settings['attendance_checkin'] ?? 'true') == 'true';
    state.endPendingReminderEnabled = (settings['end_pending_reminder'] ?? 'true') == 'true';
    state.endClassActionsEnabled = (settings['end_class_actions'] ?? 'false') == 'true';
    state.streakEnabled = (settings['attendance_streak'] ?? 'true') == 'true';
    state.highlightedSessionId = null;
    state.currentIndex = 0;

    await state.reloadAll(notify: false);
    await state.ensureRoutineSessions(notify: false);

    final smart = V26Controller.instance;
    smart
      ..studyBlocks = StudyBlock.decodeList(settings['study_blocks_v26'])
      ..dismissedInsights = _decodeSet(settings['dismissed_insights_v26'])
      ..bind(state)
      ..notifyListeners();

    await state.notifications.rescheduleEverything(
      tasks: state.tasks,
      sessions: state.classSessions,
      subjectName: state.subjectName,
      reminderMinutesForSchedule: (scheduleId) => state.scheduleById(scheduleId)?.reminderMinutes ?? 10,
      classRemindersEnabled: state.classRemindersEnabled,
      attendanceCheckInEnabled: state.attendanceCheckInEnabled,
      endPendingReminderEnabled: state.endPendingReminderEnabled,
      endClassActionsEnabled: state.endClassActionsEnabled,
    );

    state.notifyListeners();
  }
}

Set<String> _decodeSet(String? raw) {
  if (raw == null || raw.trim().isEmpty) return <String>{};
  try {
    final value = jsonDecode(raw);
    if (value is! List) return <String>{};
    return value.map((item) => '$item').where((item) => item.isNotEmpty).toSet();
  } catch (_) {
    return <String>{};
  }
}
