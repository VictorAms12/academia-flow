import 'dart:convert';

import 'models.dart';

enum InsightKind { task, attendance, exam, study, routine, performance }
enum InsightSeverity { info, attention, critical, success }

class StudyBlock {
  const StudyBlock({
    required this.id,
    required this.title,
    required this.startsAt,
    this.subjectId,
    this.durationMinutes = 60,
    this.completed = false,
    this.note = '',
  });

  final String id;
  final String title;
  final DateTime startsAt;
  final int? subjectId;
  final int durationMinutes;
  final bool completed;
  final String note;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  StudyBlock copyWith({
    String? id,
    String? title,
    DateTime? startsAt,
    int? subjectId,
    bool clearSubject = false,
    int? durationMinutes,
    bool? completed,
    String? note,
  }) =>
      StudyBlock(
        id: id ?? this.id,
        title: title ?? this.title,
        startsAt: startsAt ?? this.startsAt,
        subjectId: clearSubject ? null : subjectId ?? this.subjectId,
        durationMinutes: (durationMinutes ?? this.durationMinutes).clamp(15, 720),
        completed: completed ?? this.completed,
        note: note ?? this.note,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'startsAt': startsAt.toIso8601String(),
        'subjectId': subjectId,
        'durationMinutes': durationMinutes,
        'completed': completed,
        'note': note,
      };

  factory StudyBlock.fromJson(Map<String, dynamic> json) {
    final parsed = DateTime.tryParse('${json['startsAt'] ?? ''}');
    if (parsed == null) throw const FormatException('Data do bloco de estudo inválida.');
    return StudyBlock(
      id: '${json['id'] ?? ''}'.trim(),
      title: '${json['title'] ?? ''}'.trim(),
      startsAt: parsed,
      subjectId: (json['subjectId'] as num?)?.toInt(),
      durationMinutes: ((json['durationMinutes'] as num?)?.toInt() ?? 60).clamp(15, 720),
      completed: json['completed'] == true,
      note: '${json['note'] ?? ''}',
    );
  }

  static String encodeList(List<StudyBlock> items) => jsonEncode(items.map((item) => item.toJson()).toList());

  static List<StudyBlock> decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final items = <StudyBlock>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          final block = StudyBlock.fromJson(Map<String, dynamic>.from(item));
          if (block.id.isNotEmpty && block.title.isNotEmpty) items.add(block);
        } catch (_) {
          // Um item legado/corrompido não deve impedir o carregamento dos demais.
        }
      }
      items.sort((a, b) => a.startsAt.compareTo(b.startsAt));
      return items;
    } catch (_) {
      return [];
    }
  }
}

class AcademicInsight {
  const AcademicInsight({
    required this.id,
    required this.title,
    required this.message,
    required this.kind,
    this.severity = InsightSeverity.info,
    this.at,
    this.entityId,
  });

  final String id;
  final String title;
  final String message;
  final InsightKind kind;
  final InsightSeverity severity;
  final DateTime? at;
  final int? entityId;
}

int taskUrgencyScore(AcademicTask task, {DateTime? now}) {
  if (task.status == TaskStatus.done) return -10000;
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final due = DateTime(task.dueDate.year, task.dueDate.month, task.dueDate.day);
  final days = due.difference(today).inDays;
  final priority = switch (task.priority) {
    Priority.high => 35,
    Priority.medium => 18,
    Priority.low => 6,
  };
  final status = task.status == TaskStatus.doing ? 8 : 0;
  final dueScore = days < 0
      ? 100 + (-days * 4).clamp(0, 60)
      : days == 0
          ? 90
          : days == 1
              ? 72
              : days <= 3
                  ? 50
                  : days <= 7
                      ? 28
                      : 0;
  return dueScore + priority + status;
}

String compactDuration(int minutes) {
  final safe = minutes.clamp(0, 100000);
  final hours = safe ~/ 60;
  final rest = safe % 60;
  if (hours == 0) return '${rest}min';
  if (rest == 0) return '${hours}h';
  return '${hours}h ${rest}min';
}
