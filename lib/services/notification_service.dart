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

  static const _details = fln.NotificationDetails(
    android: fln.AndroidNotificationDetails(
      'academic_deadlines',
      'Prazos acadêmicos',
      channelDescription: 'Lembretes de provas, trabalhos e atividades',
      importance: fln.Importance.high,
      priority: fln.Priority.high,
    ),
  );

  Future<void> initialize() async {
    if (_ready) return;
    tz.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {}
    await _plugin.initialize(
      settings: const fln.InitializationSettings(
        android: fln.AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    await initialize();
    final android = _plugin.resolvePlatformSpecificImplementation<fln.AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> scheduleTask(AcademicTask task, String subjectName) async {
    await initialize();
    if (task.id == null) return;
    await cancelTask(task.id!);
    if (!task.reminderEnabled || task.status == TaskStatus.done) return;
    final due = tz.TZDateTime(tz.local, task.dueDate.year, task.dueDate.month, task.dueDate.day, 9);
    final reminders = <(int, Duration, String)>[
      (1, const Duration(days: 7), 'Falta 1 semana'),
      (2, const Duration(days: 3), 'Faltam 3 dias'),
      (3, const Duration(days: 1), 'É amanhã'),
      (4, const Duration(hours: 1), 'Prazo hoje'),
    ];
    for (final item in reminders) {
      final when = item.$1 == 4 ? tz.TZDateTime(tz.local, task.dueDate.year, task.dueDate.month, task.dueDate.day, 8) : due.subtract(item.$2);
      if (!when.isAfter(tz.TZDateTime.now(tz.local))) continue;
      await _plugin.zonedSchedule(
        id: task.id! * 10 + item.$1,
        title: '${_kindName(task.kind)} • ${item.$3}',
        body: '${task.title}${subjectName == 'Sem matéria' ? '' : ' — $subjectName'}',
        scheduledDate: when,
        notificationDetails: _details,
        androidScheduleMode: fln.AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'task:${task.id}',
      );
    }
  }

  Future<void> cancelTask(int taskId) async {
    await initialize();
    for (var i = 1; i <= 4; i++) { await _plugin.cancel(id: taskId * 10 + i); }
  }

  Future<void> rescheduleAll(List<AcademicTask> tasks, String Function(int?) subjectName) async {
    await initialize();
    await _plugin.cancelAllPendingNotifications();
    for (final task in tasks) { await scheduleTask(task, subjectName(task.subjectId)); }
  }

  Future<int> pendingCount() async { await initialize(); return (await _plugin.pendingNotificationRequests()).length; }
  String _kindName(TaskKind k) => switch(k){TaskKind.exam=>'Prova',TaskKind.seminar=>'Seminário',TaskKind.project=>'Projeto',TaskKind.reading=>'Leitura',TaskKind.other=>'Prazo',TaskKind.activity=>'Atividade'};
}
