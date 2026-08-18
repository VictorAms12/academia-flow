import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/models.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final fln.FlutterLocalNotificationsPlugin _plugin = fln.FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _unavailable = false;
  String? lastError;

  Future<void> Function(String actionId, String payload)? onRoutineAction;
  Future<void> Function(String payload)? onNotificationTap;

  static const _taskDetails = fln.NotificationDetails(
    android: fln.AndroidNotificationDetails(
      'academic_deadlines',
      'Prazos acadêmicos',
      channelDescription: 'Lembretes de provas, trabalhos e atividades',
      importance: fln.Importance.high,
      priority: fln.Priority.high,
    ),
  );

  static const _classReminderDetails = fln.NotificationDetails(
    android: fln.AndroidNotificationDetails(
      'class_reminders',
      'Lembretes de aula',
      channelDescription: 'Avisos antes do início das aulas',
      importance: fln.Importance.high,
      priority: fln.Priority.high,
    ),
  );

  static const _attendanceDetails = fln.NotificationDetails(
    android: fln.AndroidNotificationDetails(
      'attendance_checkin',
      'Check-in de presença',
      channelDescription: 'Confirmação de presença no início e ao fim da aula',
      importance: fln.Importance.max,
      priority: fln.Priority.max,
      actions: <fln.AndroidNotificationAction>[
        fln.AndroidNotificationAction('routine_present', '✓ Presente', showsUserInterface: true),
        fln.AndroidNotificationAction('routine_absent', 'Faltei', showsUserInterface: true),
        fln.AndroidNotificationAction('routine_cancelled', 'Cancelada', showsUserInterface: true),
      ],
    ),
  );

  static const _classEndDetails = fln.NotificationDetails(
    android: fln.AndroidNotificationDetails(
      'class_end',
      'Fim de aula',
      channelDescription: 'Ações rápidas quando uma aula termina',
      importance: fln.Importance.defaultImportance,
      priority: fln.Priority.defaultPriority,
    ),
  );

  bool get _portableWindows => Platform.isWindows;
  bool get available => !_unavailable;

  Future<void> initialize() async {
    if (_ready) return;
    if (_portableWindows) {
      _ready = true;
      return;
    }

    try {
      tz.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (error) {
        _recordError(error);
      }

      await _plugin.initialize(
        settings: const fln.InitializationSettings(
          android: fln.AndroidInitializationSettings('ic_stat_academia_flow'),
        ),
        onDidReceiveNotificationResponse: _handleResponse,
      );
      _ready = true;

      try {
        final launch = await _plugin.getNotificationAppLaunchDetails();
        final response = launch?.notificationResponse;
        if (launch?.didNotificationLaunchApp == true && response != null) {
          await _handleResponse(response);
        }
      } catch (error) {
        _recordError(error);
      }
    } catch (error) {
      // Notificações são um recurso auxiliar. Uma falha do plugin/recurso do
      // Android nunca deve impedir o Academia Flow de abrir e acessar os dados.
      _unavailable = true;
      _ready = true;
      _recordError(error);
    }
  }

  Future<void> _handleResponse(fln.NotificationResponse response) async {
    final payload = response.payload ?? '';
    try {
      if (response.actionId?.startsWith('routine_') == true && payload.startsWith('session:')) {
        await onRoutineAction?.call(response.actionId!, payload);
        return;
      }
      if (payload.isNotEmpty) await onNotificationTap?.call(payload);
    } catch (error) {
      _recordError(error);
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (_portableWindows) return true;
    if (_unavailable) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (error) {
      _recordError(error);
      return false;
    }
  }

  Future<void> scheduleTask(AcademicTask task, String subjectName) async {
    await initialize();
    if (_portableWindows || _unavailable || task.id == null) return;
    try {
      await _scheduleTask(task, subjectName, cancelExisting: true);
    } catch (error) {
      _recordError(error);
    }
  }

  Future<void> _scheduleTask(
    AcademicTask task,
    String subjectName, {
    required bool cancelExisting,
  }) async {
    if (task.id == null) return;
    if (cancelExisting) await _cancelTaskUnsafe(task.id!);
    if (!task.reminderEnabled || task.status == TaskStatus.done) return;

    final due = tz.TZDateTime(tz.local, task.dueDate.year, task.dueDate.month, task.dueDate.day, 9);
    final reminders = <(int, Duration, String)>[
      (1, const Duration(days: 7), 'Falta 1 semana'),
      (2, const Duration(days: 3), 'Faltam 3 dias'),
      (3, const Duration(days: 1), 'É amanhã'),
      (4, const Duration(hours: 1), 'Prazo hoje'),
    ];

    for (final item in reminders) {
      final when = item.$1 == 4
          ? tz.TZDateTime(tz.local, task.dueDate.year, task.dueDate.month, task.dueDate.day, 8)
          : due.subtract(item.$2);
      if (!when.isAfter(tz.TZDateTime.now(tz.local))) continue;
      await _plugin.zonedSchedule(
        id: task.id! * 10 + item.$1,
        title: '${_kindName(task.kind)} • ${item.$3}',
        body: '${task.title}${subjectName == 'Sem matéria' ? '' : ' — $subjectName'}',
        scheduledDate: when,
        notificationDetails: _taskDetails,
        androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'task:${task.id}',
      );
    }
  }

  Future<void> cancelTask(int taskId) async {
    await initialize();
    if (_portableWindows || _unavailable) return;
    try {
      await _cancelTaskUnsafe(taskId);
    } catch (error) {
      _recordError(error);
    }
  }

  Future<void> _cancelTaskUnsafe(int taskId) async {
    for (var i = 1; i <= 4; i++) {
      await _plugin.cancel(id: taskId * 10 + i);
    }
  }

  Future<void> rescheduleEverything({
    required List<AcademicTask> tasks,
    required List<ClassSession> sessions,
    required String Function(int?) subjectName,
    required int Function(int?) reminderMinutesForSchedule,
    required bool classRemindersEnabled,
    required bool attendanceCheckInEnabled,
    required bool endPendingReminderEnabled,
    required bool endClassActionsEnabled,
  }) async {
    await initialize();
    if (_portableWindows || _unavailable) return;

    try {
      await _plugin.cancelAllPendingNotifications();
    } catch (error) {
      _recordError(error);
      return;
    }

    for (final task in tasks) {
      if (!task.reminderEnabled || task.status == TaskStatus.done || task.id == null) continue;
      try {
        await _scheduleTask(task, subjectName(task.subjectId), cancelExisting: false);
      } catch (error) {
        _recordError(error);
      }
    }

    final now = DateTime.now();
    for (final session in sessions) {
      if (session.id == null || session.status == AttendanceStatus.cancelled || !session.endsAt.isAfter(now)) continue;
      if (session.status != AttendanceStatus.pending && !endClassActionsEnabled) continue;
      try {
        await _scheduleClassSession(
          session,
          subjectName(session.subjectId),
          reminderMinutes: reminderMinutesForSchedule(session.scheduleId),
          classRemindersEnabled: classRemindersEnabled,
          attendanceCheckInEnabled: attendanceCheckInEnabled,
          endPendingReminderEnabled: endPendingReminderEnabled,
          endClassActionsEnabled: endClassActionsEnabled,
        );
      } catch (error) {
        _recordError(error);
      }
    }
  }

  Future<void> scheduleClassSession(
    ClassSession session,
    String subjectName, {
    required int reminderMinutes,
    required bool classRemindersEnabled,
    required bool attendanceCheckInEnabled,
    required bool endPendingReminderEnabled,
    required bool endClassActionsEnabled,
  }) async {
    await initialize();
    if (_portableWindows || _unavailable || session.id == null || session.status == AttendanceStatus.cancelled) return;
    try {
      await _scheduleClassSession(
        session,
        subjectName,
        reminderMinutes: reminderMinutes,
        classRemindersEnabled: classRemindersEnabled,
        attendanceCheckInEnabled: attendanceCheckInEnabled,
        endPendingReminderEnabled: endPendingReminderEnabled,
        endClassActionsEnabled: endClassActionsEnabled,
      );
    } catch (error) {
      _recordError(error);
    }
  }

  Future<void> _scheduleClassSession(
    ClassSession session,
    String subjectName, {
    required int reminderMinutes,
    required bool classRemindersEnabled,
    required bool attendanceCheckInEnabled,
    required bool endPendingReminderEnabled,
    required bool endClassActionsEnabled,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    final start = _tzFrom(session.startsAt);
    final end = _tzFrom(session.endsAt);
    final base = 1000000 + session.id! * 10;
    final countLabel = session.classCount == 1 ? '1 aula' : '${session.classCount} aulas';

    if (classRemindersEnabled && reminderMinutes > 0) {
      final before = start.subtract(Duration(minutes: reminderMinutes));
      if (before.isAfter(now)) {
        await _plugin.zonedSchedule(
          id: base + 1,
          title: '$subjectName começa em $reminderMinutes min',
          body: '${session.start}–${session.end} • $countLabel${session.room.isEmpty ? '' : ' • ${session.room}'}',
          scheduledDate: before,
          notificationDetails: _classReminderDetails,
          androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
          payload: 'session:${session.id}',
        );
      }
    }

    if (attendanceCheckInEnabled && session.status == AttendanceStatus.pending && start.isAfter(now)) {
      await _plugin.zonedSchedule(
        id: base + 2,
        title: '📚 $subjectName começou',
        body: 'Você está presente? • $countLabel',
        scheduledDate: start,
        notificationDetails: _attendanceDetails,
        androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'session:${session.id}',
      );
    }

    if (session.status == AttendanceStatus.pending && end.isAfter(now) && endPendingReminderEnabled) {
      await _plugin.zonedSchedule(
        id: base + 3,
        title: 'Presença pendente • $subjectName',
        body: 'A aula terminou. Você estava presente?',
        scheduledDate: end,
        notificationDetails: _attendanceDetails,
        androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'session:${session.id}',
      );
    } else if (endClassActionsEnabled && end.isAfter(now)) {
      await _plugin.zonedSchedule(
        id: base + 4,
        title: '$subjectName terminou',
        body: 'Abra a aula para adicionar anotação, material ou atividade.',
        scheduledDate: end,
        notificationDetails: _classEndDetails,
        androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'session:${session.id}',
      );
    }
  }

  Future<void> cancelClassSession(int sessionId) async {
    await initialize();
    if (_portableWindows || _unavailable) return;
    try {
      final base = 1000000 + sessionId * 10;
      for (var i = 1; i <= 4; i++) {
        await _plugin.cancel(id: base + i);
      }
    } catch (error) {
      _recordError(error);
    }
  }

  Future<int> pendingCount() async {
    await initialize();
    if (_portableWindows || _unavailable) return 0;
    try {
      return (await _plugin.pendingNotificationRequests()).length;
    } catch (error) {
      _recordError(error);
      return 0;
    }
  }

  void _recordError(Object error) {
    lastError = error.toString();
  }

  tz.TZDateTime _tzFrom(DateTime value) => tz.TZDateTime(
        tz.local,
        value.year,
        value.month,
        value.day,
        value.hour,
        value.minute,
      );

  String _kindName(TaskKind k) => switch (k) {
        TaskKind.exam => 'Prova',
        TaskKind.seminar => 'Seminário',
        TaskKind.project => 'Projeto',
        TaskKind.reading => 'Leitura',
        TaskKind.other => 'Prazo',
        TaskKind.activity => 'Atividade',
      };
}
