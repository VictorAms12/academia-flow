import 'package:flutter/material.dart';

enum TaskStatus { todo, doing, done }
enum Priority { high, medium, low }

class AcademicTask {
  AcademicTask({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.priority,
    required this.status,
    this.description = '',
  });

  final int id;
  final String title;
  final String subject;
  final DateTime dueDate;
  final Priority priority;
  TaskStatus status;
  final String description;
}

class Subject {
  const Subject({
    required this.id,
    required this.name,
    required this.professor,
    required this.room,
    required this.attendance,
    required this.grade,
    required this.icon,
    required this.color,
  });

  final int id;
  final String name;
  final String professor;
  final String room;
  final int attendance;
  final double grade;
  final IconData icon;
  final Color color;
}

class ScheduleEntry {
  const ScheduleEntry({
    required this.day,
    required this.start,
    required this.end,
    required this.subject,
    required this.room,
  });

  final int day;
  final String start;
  final String end;
  final String subject;
  final String room;
}
