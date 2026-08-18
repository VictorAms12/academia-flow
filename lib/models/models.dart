import 'dart:convert';

class Subject {
  const Subject({
    this.id,
    required this.name,
    this.professor = '',
    this.room = '',
    this.totalClasses = 0,
    this.plannedClasses = 0,
    this.absences = 0,
    this.minAttendance,
  });

  final int? id;
  final String name;
  final String professor;
  final String room;
  final int totalClasses;
  final int plannedClasses;
  final int absences;
  final double? minAttendance;

  double get attendance {
    if (totalClasses <= 0) return 100;
    final present = (totalClasses - absences).clamp(0, totalClasses).toInt();
    return (present / totalClasses) * 100;
  }

  Subject copyWith({
    int? id,
    String? name,
    String? professor,
    String? room,
    int? totalClasses,
    int? plannedClasses,
    int? absences,
    double? minAttendance,
    bool clearMinAttendance = false,
  }) =>
      Subject(
        id: id ?? this.id,
        name: name ?? this.name,
        professor: professor ?? this.professor,
        room: room ?? this.room,
        totalClasses: totalClasses ?? this.totalClasses,
        plannedClasses: plannedClasses ?? this.plannedClasses,
        absences: absences ?? this.absences,
        minAttendance: clearMinAttendance ? null : minAttendance ?? this.minAttendance,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'professor': professor,
        'room': room,
        'total_classes': totalClasses,
        'planned_classes': plannedClasses,
        'absences': absences,
        'min_attendance': minAttendance,
      };

  factory Subject.fromMap(Map<String, Object?> map) => Subject(
        id: map['id'] as int?,
        name: _text(map['name']),
        professor: _text(map['professor']),
        room: _text(map['room']),
        totalClasses: _nonNegativeInt(map['total_classes']),
        plannedClasses: _nonNegativeInt(map['planned_classes']),
        absences: _nonNegativeInt(map['absences']),
        minAttendance: (map['min_attendance'] as num?)?.toDouble(),
      );
}

enum TaskStatus { todo, doing, done }
enum Priority { high, medium, low }
enum TaskKind { activity, exam, seminar, project, reading, other }

class AcademicTask {
  const AcademicTask({
    this.id,
    required this.title,
    this.subjectId,
    required this.dueDate,
    this.priority = Priority.medium,
    this.status = TaskStatus.todo,
    this.kind = TaskKind.activity,
    this.reminderEnabled = true,
    this.description = '',
    this.checklist = const [],
    this.completedSteps = const [],
    this.sessionId,
  });

  final int? id;
  final String title;
  final int? subjectId;
  final DateTime dueDate;
  final Priority priority;
  final TaskStatus status;
  final TaskKind kind;
  final bool reminderEnabled;
  final String description;
  final List<String> checklist;
  final List<int> completedSteps;
  final int? sessionId;

  AcademicTask copyWith({
    int? id,
    String? title,
    int? subjectId,
    bool clearSubject = false,
    DateTime? dueDate,
    Priority? priority,
    TaskStatus? status,
    TaskKind? kind,
    bool? reminderEnabled,
    String? description,
    List<String>? checklist,
    List<int>? completedSteps,
    int? sessionId,
    bool clearSession = false,
  }) =>
      AcademicTask(
        id: id ?? this.id,
        title: title ?? this.title,
        subjectId: clearSubject ? null : subjectId ?? this.subjectId,
        dueDate: dueDate ?? this.dueDate,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        kind: kind ?? this.kind,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        description: description ?? this.description,
        checklist: checklist ?? this.checklist,
        completedSteps: completedSteps ?? this.completedSteps,
        sessionId: clearSession ? null : sessionId ?? this.sessionId,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'subject_id': subjectId,
        'due_date': dueDate.toIso8601String(),
        'priority': priority.index,
        'status': status.index,
        'kind': kind.index,
        'reminder_enabled': reminderEnabled ? 1 : 0,
        'description': description,
        'checklist': jsonEncode(checklist),
        'completed_steps': jsonEncode(completedSteps),
        'session_id': sessionId,
      };

  factory AcademicTask.fromMap(Map<String, Object?> map) {
    final checklist = _stringList(map['checklist']);
    final completed = _intList(map['completed_steps'])
        .where((index) => index >= 0 && index < checklist.length)
        .toSet()
        .toList()
      ..sort();
    return AcademicTask(
      id: map['id'] as int?,
      title: _text(map['title']),
      subjectId: map['subject_id'] as int?,
      dueDate: _date(map['due_date']),
      priority: _enumValue(Priority.values, map['priority'], Priority.medium),
      status: _enumValue(TaskStatus.values, map['status'], TaskStatus.todo),
      kind: _enumValue(TaskKind.values, map['kind'], TaskKind.activity),
      reminderEnabled: _boolInt(map['reminder_enabled'], fallback: true),
      description: _text(map['description']),
      checklist: checklist,
      completedSteps: completed,
      sessionId: map['session_id'] as int?,
    );
  }
}

class Grade {
  const Grade({this.id, required this.subjectId, required this.title, required this.value, this.weight = 1, required this.date});
  final int? id;
  final int subjectId;
  final String title;
  final double value;
  final double weight;
  final DateTime date;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'subject_id': subjectId,
        'title': title,
        'value': value,
        'weight': weight,
        'date': date.toIso8601String(),
      };

  factory Grade.fromMap(Map<String, Object?> map) => Grade(
        id: map['id'] as int?,
        subjectId: (map['subject_id'] as num?)?.toInt() ?? 0,
        title: _text(map['title']),
        value: (map['value'] as num?)?.toDouble() ?? 0,
        weight: ((map['weight'] as num?)?.toDouble() ?? 1).clamp(0.0001, double.infinity),
        date: _date(map['date']),
      );
}

class ScheduleEntry {
  const ScheduleEntry({
    this.id,
    required this.subjectId,
    required this.day,
    required this.start,
    required this.end,
    this.room = '',
    this.classCount = 1,
    this.reminderMinutes = 10,
  });
  final int? id;
  final int subjectId;
  final int day;
  final String start;
  final String end;
  final String room;
  final int classCount;
  final int reminderMinutes;

  ScheduleEntry copyWith({
    int? id,
    int? subjectId,
    int? day,
    String? start,
    String? end,
    String? room,
    int? classCount,
    int? reminderMinutes,
  }) =>
      ScheduleEntry(
        id: id ?? this.id,
        subjectId: subjectId ?? this.subjectId,
        day: day ?? this.day,
        start: start ?? this.start,
        end: end ?? this.end,
        room: room ?? this.room,
        classCount: classCount ?? this.classCount,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'subject_id': subjectId,
        'day': day,
        'start_time': start,
        'end_time': end,
        'room': room,
        'class_count': classCount,
        'reminder_minutes': reminderMinutes,
      };

  factory ScheduleEntry.fromMap(Map<String, Object?> map) => ScheduleEntry(
        id: map['id'] as int?,
        subjectId: (map['subject_id'] as num?)?.toInt() ?? 0,
        day: ((map['day'] as num?)?.toInt() ?? 1).clamp(1, 7),
        start: _timeText(map['start_time'], fallback: '19:00'),
        end: _timeText(map['end_time'], fallback: '20:40'),
        room: _text(map['room']),
        classCount: ((map['class_count'] as num?)?.toInt() ?? 1).clamp(1, 8),
        reminderMinutes: ((map['reminder_minutes'] as num?)?.toInt() ?? 10).clamp(0, 120),
      );
}

enum AttendanceStatus { pending, present, absent, cancelled }
enum ClassSessionKind { regular, extra, makeup }

class ClassSession {
  const ClassSession({
    this.id,
    required this.subjectId,
    this.scheduleId,
    required this.date,
    required this.start,
    required this.end,
    this.room = '',
    this.classCount = 1,
    this.status = AttendanceStatus.pending,
    this.kind = ClassSessionKind.regular,
    this.note = '',
    this.makeupForSessionId,
    required this.createdAt,
  });

  final int? id;
  final int subjectId;
  final int? scheduleId;
  final DateTime date;
  final String start;
  final String end;
  final String room;
  final int classCount;
  final AttendanceStatus status;
  final ClassSessionKind kind;
  final String note;
  final int? makeupForSessionId;
  final DateTime createdAt;

  DateTime get startsAt => _combine(date, start);
  DateTime get endsAt => _combine(date, end);

  ClassSession copyWith({
    int? id,
    int? subjectId,
    int? scheduleId,
    bool clearSchedule = false,
    DateTime? date,
    String? start,
    String? end,
    String? room,
    int? classCount,
    AttendanceStatus? status,
    ClassSessionKind? kind,
    String? note,
    int? makeupForSessionId,
    bool clearMakeupFor = false,
    DateTime? createdAt,
  }) =>
      ClassSession(
        id: id ?? this.id,
        subjectId: subjectId ?? this.subjectId,
        scheduleId: clearSchedule ? null : scheduleId ?? this.scheduleId,
        date: date ?? this.date,
        start: start ?? this.start,
        end: end ?? this.end,
        room: room ?? this.room,
        classCount: classCount ?? this.classCount,
        status: status ?? this.status,
        kind: kind ?? this.kind,
        note: note ?? this.note,
        makeupForSessionId: clearMakeupFor ? null : makeupForSessionId ?? this.makeupForSessionId,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'subject_id': subjectId,
        'schedule_id': scheduleId,
        'date': _dateKey(date),
        'start_time': start,
        'end_time': end,
        'room': room,
        'class_count': classCount,
        'status': status.index,
        'kind': kind.index,
        'note': note,
        'makeup_for_session_id': makeupForSessionId,
        'created_at': createdAt.toIso8601String(),
      };

  factory ClassSession.fromMap(Map<String, Object?> map) => ClassSession(
        id: map['id'] as int?,
        subjectId: (map['subject_id'] as num?)?.toInt() ?? 0,
        scheduleId: map['schedule_id'] as int?,
        date: _date(map['date']),
        start: _timeText(map['start_time'], fallback: '00:00'),
        end: _timeText(map['end_time'], fallback: '00:01'),
        room: _text(map['room']),
        classCount: ((map['class_count'] as num?)?.toInt() ?? 1).clamp(1, 8),
        status: _enumValue(AttendanceStatus.values, map['status'], AttendanceStatus.pending),
        kind: _enumValue(ClassSessionKind.values, map['kind'], ClassSessionKind.regular),
        note: _text(map['note']),
        makeupForSessionId: map['makeup_for_session_id'] as int?,
        createdAt: _date(map['created_at']),
      );
}

enum AcademicEventKind { holiday, recess, cancellation, examWeek, academicEvent }

class AcademicCalendarEvent {
  const AcademicCalendarEvent({
    this.id,
    required this.date,
    required this.title,
    this.kind = AcademicEventKind.academicEvent,
    this.subjectId,
    this.blocksClasses = false,
  });
  final int? id;
  final DateTime date;
  final String title;
  final AcademicEventKind kind;
  final int? subjectId;
  final bool blocksClasses;

  AcademicCalendarEvent copyWith({
    int? id,
    DateTime? date,
    String? title,
    AcademicEventKind? kind,
    int? subjectId,
    bool clearSubject = false,
    bool? blocksClasses,
  }) =>
      AcademicCalendarEvent(
        id: id ?? this.id,
        date: date ?? this.date,
        title: title ?? this.title,
        kind: kind ?? this.kind,
        subjectId: clearSubject ? null : subjectId ?? this.subjectId,
        blocksClasses: blocksClasses ?? this.blocksClasses,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'date': _dateKey(date),
        'title': title,
        'kind': kind.index,
        'subject_id': subjectId,
        'blocks_classes': blocksClasses ? 1 : 0,
      };

  factory AcademicCalendarEvent.fromMap(Map<String, Object?> map) => AcademicCalendarEvent(
        id: map['id'] as int?,
        date: _date(map['date']),
        title: _text(map['title']),
        kind: _enumValue(AcademicEventKind.values, map['kind'], AcademicEventKind.academicEvent),
        subjectId: map['subject_id'] as int?,
        blocksClasses: _boolInt(map['blocks_classes']),
      );
}

class AcademicNote {
  const AcademicNote({
    this.id,
    this.subjectId,
    required this.title,
    this.content = '',
    this.link = '',
    this.tags = '',
    this.pinned = false,
    required this.createdAt,
    this.sessionId,
  });
  final int? id;
  final int? subjectId;
  final String title;
  final String content;
  final String link;
  final String tags;
  final bool pinned;
  final DateTime createdAt;
  final int? sessionId;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'subject_id': subjectId,
        'title': title,
        'content': content,
        'link': link,
        'tags': tags,
        'pinned': pinned ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'session_id': sessionId,
      };

  factory AcademicNote.fromMap(Map<String, Object?> map) => AcademicNote(
        id: map['id'] as int?,
        subjectId: map['subject_id'] as int?,
        title: _text(map['title']),
        content: _text(map['content']),
        link: _text(map['link']),
        tags: _text(map['tags']),
        pinned: _boolInt(map['pinned']),
        createdAt: _date(map['created_at']),
        sessionId: map['session_id'] as int?,
      );
}

enum MaterialKind { pdf, slides, video, link, repository, document, other }

class MaterialResource {
  const MaterialResource({
    this.id,
    required this.subjectId,
    required this.title,
    this.url = '',
    this.description = '',
    this.kind = MaterialKind.link,
    required this.createdAt,
    this.sessionId,
  });
  final int? id;
  final int subjectId;
  final String title;
  final String url;
  final String description;
  final MaterialKind kind;
  final DateTime createdAt;
  final int? sessionId;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'subject_id': subjectId,
        'title': title,
        'url': url,
        'description': description,
        'kind': kind.index,
        'created_at': createdAt.toIso8601String(),
        'session_id': sessionId,
      };

  factory MaterialResource.fromMap(Map<String, Object?> map) => MaterialResource(
        id: map['id'] as int?,
        subjectId: (map['subject_id'] as num?)?.toInt() ?? 0,
        title: _text(map['title']),
        url: _text(map['url']),
        description: _text(map['description']),
        kind: _enumValue(MaterialKind.values, map['kind'], MaterialKind.link),
        createdAt: _date(map['created_at']),
        sessionId: map['session_id'] as int?,
      );
}

T _enumValue<T>(List<T> values, Object? raw, T fallback) {
  final index = raw is num ? raw.toInt() : int.tryParse('$raw');
  if (index == null || index < 0 || index >= values.length) return fallback;
  return values[index];
}

String _text(Object? value) => value?.toString() ?? '';
int _nonNegativeInt(Object? value) => ((value as num?)?.toInt() ?? int.tryParse('$value') ?? 0).clamp(0, 1 << 31);
bool _boolInt(Object? value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().toLowerCase();
  if (text == 'true' || text == '1') return true;
  if (text == 'false' || text == '0') return false;
  return fallback;
}

DateTime _date(Object? value) => DateTime.tryParse(_text(value)) ?? DateTime.fromMillisecondsSinceEpoch(0);

List<String> _stringList(Object? raw) {
  try {
    final decoded = jsonDecode(_text(raw).isEmpty ? '[]' : _text(raw));
    if (decoded is! List) return const [];
    return decoded.map((e) => e?.toString().trim() ?? '').where((e) => e.isNotEmpty).toList();
  } catch (_) {
    return const [];
  }
}

List<int> _intList(Object? raw) {
  try {
    final decoded = jsonDecode(_text(raw).isEmpty ? '[]' : _text(raw));
    if (decoded is! List) return const [];
    return decoded.map((e) => e is num ? e.toInt() : int.tryParse('$e')).whereType<int>().toList();
  } catch (_) {
    return const [];
  }
}

String _timeText(Object? raw, {required String fallback}) {
  final value = _text(raw).trim();
  final match = RegExp(r'^(\d{1,2}):(\d{1,2})$').firstMatch(value);
  if (match == null) return fallback;
  final hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return fallback;
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

DateTime _combine(DateTime date, String hhmm) {
  final safe = _timeText(hhmm, fallback: '00:00').split(':');
  return DateTime(date.year, date.month, date.day, int.parse(safe[0]), int.parse(safe[1]));
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
