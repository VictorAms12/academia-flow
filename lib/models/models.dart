import 'dart:convert';

class Subject {
  const Subject({
    this.id,
    required this.name,
    this.professor = '',
    this.room = '',
    this.totalClasses = 0,
    this.absences = 0,
  });

  final int? id;
  final String name;
  final String professor;
  final String room;
  final int totalClasses;
  final int absences;

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
    int? absences,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      professor: professor ?? this.professor,
      room: room ?? this.room,
      totalClasses: totalClasses ?? this.totalClasses,
      absences: absences ?? this.absences,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'professor': professor,
        'room': room,
        'total_classes': totalClasses,
        'absences': absences,
      };

  factory Subject.fromMap(Map<String, Object?> map) => Subject(
        id: map['id'] as int?,
        name: map['name'] as String,
        professor: (map['professor'] as String?) ?? '',
        room: (map['room'] as String?) ?? '',
        totalClasses: (map['total_classes'] as int?) ?? 0,
        absences: (map['absences'] as int?) ?? 0,
      );
}

enum TaskStatus { todo, doing, done }
enum Priority { high, medium, low }

class AcademicTask {
  const AcademicTask({
    this.id,
    required this.title,
    this.subjectId,
    required this.dueDate,
    this.priority = Priority.medium,
    this.status = TaskStatus.todo,
    this.description = '',
    this.checklist = const [],
    this.completedSteps = const [],
  });

  final int? id;
  final String title;
  final int? subjectId;
  final DateTime dueDate;
  final Priority priority;
  final TaskStatus status;
  final String description;
  final List<String> checklist;
  final List<int> completedSteps;

  AcademicTask copyWith({
    int? id,
    String? title,
    int? subjectId,
    bool clearSubject = false,
    DateTime? dueDate,
    Priority? priority,
    TaskStatus? status,
    String? description,
    List<String>? checklist,
    List<int>? completedSteps,
  }) {
    return AcademicTask(
      id: id ?? this.id,
      title: title ?? this.title,
      subjectId: clearSubject ? null : subjectId ?? this.subjectId,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      description: description ?? this.description,
      checklist: checklist ?? this.checklist,
      completedSteps: completedSteps ?? this.completedSteps,
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'subject_id': subjectId,
        'due_date': dueDate.toIso8601String(),
        'priority': priority.index,
        'status': status.index,
        'description': description,
        'checklist': jsonEncode(checklist),
        'completed_steps': jsonEncode(completedSteps),
      };

  factory AcademicTask.fromMap(Map<String, Object?> map) => AcademicTask(
        id: map['id'] as int?,
        title: map['title'] as String,
        subjectId: map['subject_id'] as int?,
        dueDate: DateTime.parse(map['due_date'] as String),
        priority: Priority.values[(map['priority'] as int?) ?? 1],
        status: TaskStatus.values[(map['status'] as int?) ?? 0],
        description: (map['description'] as String?) ?? '',
        checklist: List<String>.from(
          jsonDecode((map['checklist'] as String?) ?? '[]') as List,
        ),
        completedSteps: List<int>.from(
          jsonDecode((map['completed_steps'] as String?) ?? '[]') as List,
        ),
      );
}

class Grade {
  const Grade({
    this.id,
    required this.subjectId,
    required this.title,
    required this.value,
    this.weight = 1,
    required this.date,
  });

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
        subjectId: map['subject_id'] as int,
        title: map['title'] as String,
        value: (map['value'] as num).toDouble(),
        weight: (map['weight'] as num?)?.toDouble() ?? 1,
        date: DateTime.parse(map['date'] as String),
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
  });

  final int? id;
  final int subjectId;
  final int day;
  final String start;
  final String end;
  final String room;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'subject_id': subjectId,
        'day': day,
        'start_time': start,
        'end_time': end,
        'room': room,
      };

  factory ScheduleEntry.fromMap(Map<String, Object?> map) => ScheduleEntry(
        id: map['id'] as int?,
        subjectId: map['subject_id'] as int,
        day: map['day'] as int,
        start: map['start_time'] as String,
        end: map['end_time'] as String,
        room: (map['room'] as String?) ?? '',
      );
}

class AcademicNote {
  const AcademicNote({
    this.id,
    this.subjectId,
    required this.title,
    this.content = '',
    this.link = '',
    required this.createdAt,
  });

  final int? id;
  final int? subjectId;
  final String title;
  final String content;
  final String link;
  final DateTime createdAt;

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'subject_id': subjectId,
        'title': title,
        'content': content,
        'link': link,
        'created_at': createdAt.toIso8601String(),
      };

  factory AcademicNote.fromMap(Map<String, Object?> map) => AcademicNote(
        id: map['id'] as int?,
        subjectId: map['subject_id'] as int?,
        title: map['title'] as String,
        content: (map['content'] as String?) ?? '',
        link: (map['link'] as String?) ?? '',
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
