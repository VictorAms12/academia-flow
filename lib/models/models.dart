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
        name: map['name'] as String,
        professor: (map['professor'] as String?) ?? '',
        room: (map['room'] as String?) ?? '',
        totalClasses: (map['total_classes'] as int?) ?? 0,
        plannedClasses: (map['planned_classes'] as int?) ?? 0,
        absences: (map['absences'] as int?) ?? 0,
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

  factory AcademicTask.fromMap(Map<String, Object?> map) => AcademicTask(
        id: map['id'] as int?,
        title: map['title'] as String,
        subjectId: map['subject_id'] as int?,
        dueDate: DateTime.parse(map['due_date'] as String),
        priority: Priority.values[(map['priority'] as int?) ?? 1],
        status: TaskStatus.values[(map['status'] as int?) ?? 0],
        kind: TaskKind.values[(map['kind'] as int?) ?? 0],
        reminderEnabled: ((map['reminder_enabled'] as int?) ?? 1) == 1,
        description: (map['description'] as String?) ?? '',
        checklist: List<String>.from(jsonDecode((map['checklist'] as String?) ?? '[]') as List),
        completedSteps: List<int>.from(jsonDecode((map['completed_steps'] as String?) ?? '[]') as List),
        sessionId: map['session_id'] as int?,
      );
}

class Grade {
  const Grade({this.id, required this.subjectId, required this.title, required this.value, this.weight = 1, required this.date});
  final int? id;
  final int subjectId;
  final String title;
  final double value;
  final double weight;
  final DateTime date;
  Map<String, Object?> toMap() => {if (id != null) 'id': id, 'subject_id': subjectId, 'title': title, 'value': value, 'weight': weight, 'date': date.toIso8601String()};
  factory Grade.fromMap(Map<String, Object?> map) => Grade(id: map['id'] as int?, subjectId: map['subject_id'] as int, title: map['title'] as String, value: (map['value'] as num).toDouble(), weight: (map['weight'] as num?)?.toDouble() ?? 1, date: DateTime.parse(map['date'] as String));
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
        subjectId: map['subject_id'] as int,
        day: map['day'] as int,
        start: map['start_time'] as String,
        end: map['end_time'] as String,
        room: (map['room'] as String?) ?? '',
        classCount: (map['class_count'] as int?) ?? 1,
        reminderMinutes: (map['reminder_minutes'] as int?) ?? 10,
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
        subjectId: map['subject_id'] as int,
        scheduleId: map['schedule_id'] as int?,
        date: DateTime.parse(map['date'] as String),
        start: map['start_time'] as String,
        end: map['end_time'] as String,
        room: (map['room'] as String?) ?? '',
        classCount: (map['class_count'] as int?) ?? 1,
        status: AttendanceStatus.values[(map['status'] as int?) ?? 0],
        kind: ClassSessionKind.values[(map['kind'] as int?) ?? 0],
        note: (map['note'] as String?) ?? '',
        makeupForSessionId: map['makeup_for_session_id'] as int?,
        createdAt: DateTime.parse(map['created_at'] as String),
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
        date: DateTime.parse(map['date'] as String),
        title: map['title'] as String,
        kind: AcademicEventKind.values[(map['kind'] as int?) ?? 4],
        subjectId: map['subject_id'] as int?,
        blocksClasses: ((map['blocks_classes'] as int?) ?? 0) == 1,
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
        title: map['title'] as String,
        content: (map['content'] as String?) ?? '',
        link: (map['link'] as String?) ?? '',
        tags: (map['tags'] as String?) ?? '',
        pinned: ((map['pinned'] as int?) ?? 0) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
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
        subjectId: map['subject_id'] as int,
        title: map['title'] as String,
        url: (map['url'] as String?) ?? '',
        description: (map['description'] as String?) ?? '',
        kind: MaterialKind.values[(map['kind'] as int?) ?? 2],
        createdAt: DateTime.parse(map['created_at'] as String),
        sessionId: map['session_id'] as int?,
      );
}

DateTime _combine(DateTime date, String hhmm) {
  final p = hhmm.split(':');
  final h = int.tryParse(p.first) ?? 0;
  final m = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
  return DateTime(date.year, date.month, date.day, h, m);
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
