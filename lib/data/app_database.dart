import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final base = await getDatabasesPath();
    final path = p.join(base, 'academia_flow_v2.db');
    _database = await openDatabase(
      path,
      version: 4,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    await db.execute('''CREATE TABLE subjects(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      professor TEXT NOT NULL DEFAULT '',
      room TEXT NOT NULL DEFAULT '',
      total_classes INTEGER NOT NULL DEFAULT 0,
      planned_classes INTEGER NOT NULL DEFAULT 0,
      absences INTEGER NOT NULL DEFAULT 0,
      min_attendance REAL
    )''');
    await db.execute('''CREATE TABLE schedules(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subject_id INTEGER NOT NULL,
      day INTEGER NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL,
      room TEXT NOT NULL DEFAULT '',
      class_count INTEGER NOT NULL DEFAULT 1,
      reminder_minutes INTEGER NOT NULL DEFAULT 10,
      FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE class_sessions(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subject_id INTEGER NOT NULL,
      schedule_id INTEGER,
      date TEXT NOT NULL,
      start_time TEXT NOT NULL,
      end_time TEXT NOT NULL,
      room TEXT NOT NULL DEFAULT '',
      class_count INTEGER NOT NULL DEFAULT 1,
      status INTEGER NOT NULL DEFAULT 0,
      kind INTEGER NOT NULL DEFAULT 0,
      note TEXT NOT NULL DEFAULT '',
      makeup_for_session_id INTEGER,
      created_at TEXT NOT NULL,
      FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
      FOREIGN KEY(schedule_id) REFERENCES schedules(id) ON DELETE SET NULL,
      FOREIGN KEY(makeup_for_session_id) REFERENCES class_sessions(id) ON DELETE SET NULL
    )''');
    await db.execute('CREATE UNIQUE INDEX idx_class_session_schedule_date ON class_sessions(schedule_id, date) WHERE schedule_id IS NOT NULL');
    await db.execute('''CREATE TABLE academic_calendar(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      title TEXT NOT NULL,
      kind INTEGER NOT NULL DEFAULT 4,
      subject_id INTEGER,
      blocks_classes INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE tasks(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      subject_id INTEGER,
      due_date TEXT NOT NULL,
      priority INTEGER NOT NULL DEFAULT 1,
      status INTEGER NOT NULL DEFAULT 0,
      kind INTEGER NOT NULL DEFAULT 0,
      reminder_enabled INTEGER NOT NULL DEFAULT 1,
      description TEXT NOT NULL DEFAULT '',
      checklist TEXT NOT NULL DEFAULT '[]',
      completed_steps TEXT NOT NULL DEFAULT '[]',
      session_id INTEGER,
      FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE SET NULL
    )''');
    await db.execute('''CREATE TABLE grades(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subject_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      value REAL NOT NULL,
      weight REAL NOT NULL DEFAULT 1,
      date TEXT NOT NULL,
      FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
    )''');
    await db.execute('''CREATE TABLE notes(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subject_id INTEGER,
      title TEXT NOT NULL,
      content TEXT NOT NULL DEFAULT '',
      link TEXT NOT NULL DEFAULT '',
      tags TEXT NOT NULL DEFAULT '',
      pinned INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      session_id INTEGER,
      FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE SET NULL
    )''');
    await db.execute('''CREATE TABLE materials(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subject_id INTEGER NOT NULL,
      title TEXT NOT NULL,
      url TEXT NOT NULL DEFAULT '',
      description TEXT NOT NULL DEFAULT '',
      kind INTEGER NOT NULL DEFAULT 3,
      created_at TEXT NOT NULL,
      session_id INTEGER,
      FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
    )''');
    await _createIndexes(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE subjects ADD COLUMN planned_classes INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE tasks ADD COLUMN kind INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE tasks ADD COLUMN reminder_enabled INTEGER NOT NULL DEFAULT 1');
      await db.execute("ALTER TABLE notes ADD COLUMN tags TEXT NOT NULL DEFAULT ''");
      await db.execute('ALTER TABLE notes ADD COLUMN pinned INTEGER NOT NULL DEFAULT 0');
      await db.execute('''CREATE TABLE IF NOT EXISTS materials(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        url TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        kind INTEGER NOT NULL DEFAULT 3,
        created_at TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )''');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE subjects ADD COLUMN min_attendance REAL');
      await db.execute('ALTER TABLE schedules ADD COLUMN class_count INTEGER NOT NULL DEFAULT 1');
      await db.execute('ALTER TABLE schedules ADD COLUMN reminder_minutes INTEGER NOT NULL DEFAULT 10');
      await db.execute('ALTER TABLE tasks ADD COLUMN session_id INTEGER');
      await db.execute('ALTER TABLE notes ADD COLUMN session_id INTEGER');
      await db.execute('ALTER TABLE materials ADD COLUMN session_id INTEGER');
      await db.execute('''CREATE TABLE IF NOT EXISTS class_sessions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL,
        schedule_id INTEGER,
        date TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        room TEXT NOT NULL DEFAULT '',
        class_count INTEGER NOT NULL DEFAULT 1,
        status INTEGER NOT NULL DEFAULT 0,
        kind INTEGER NOT NULL DEFAULT 0,
        note TEXT NOT NULL DEFAULT '',
        makeup_for_session_id INTEGER,
        created_at TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
        FOREIGN KEY(schedule_id) REFERENCES schedules(id) ON DELETE SET NULL,
        FOREIGN KEY(makeup_for_session_id) REFERENCES class_sessions(id) ON DELETE SET NULL
      )''');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_class_session_schedule_date ON class_sessions(schedule_id, date) WHERE schedule_id IS NOT NULL');
      await db.execute('''CREATE TABLE IF NOT EXISTS academic_calendar(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        title TEXT NOT NULL,
        kind INTEGER NOT NULL DEFAULT 4,
        subject_id INTEGER,
        blocks_classes INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )''');
    }
    if (oldVersion < 4) {
      await _detachOrphanSessionLinks(db);
      await _createIndexes(db);
    }
  }

  Future<void> _createIndexes(DatabaseExecutor db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_schedules_subject_day ON schedules(subject_id, day, start_time)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_subject_date ON class_sessions(subject_id, date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sessions_date_status ON class_sessions(date, status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_subject_due ON tasks(subject_id, due_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_grades_subject_date ON grades(subject_id, date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_notes_subject_created ON notes(subject_id, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_materials_subject_created ON materials(subject_id, created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_calendar_date ON academic_calendar(date)');
  }

  Future<void> _detachOrphanSessionLinks(DatabaseExecutor db) async {
    for (final table in const ['tasks', 'notes', 'materials']) {
      await db.execute(
        'UPDATE $table SET session_id = NULL WHERE session_id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM class_sessions WHERE class_sessions.id = $table.session_id)',
      );
    }
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<Map<String, String>> getSettings() async {
    final rows = await (await database).query('settings');
    return {for (final row in rows) row['key'] as String: row['value'] as String};
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Subject>> getSubjects() async =>
      (await (await database).query('subjects', orderBy: 'name COLLATE NOCASE')).map(Subject.fromMap).toList();

  Future<Subject> saveSubject(Subject item) async {
    final db = await database;
    if (item.id == null) return item.copyWith(id: await db.insert('subjects', item.toMap()));
    await db.update('subjects', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item;
  }

  Future<void> deleteSubject(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in const ['tasks', 'notes', 'materials']) {
        await txn.execute(
          'UPDATE $table SET session_id = NULL WHERE session_id IN (SELECT id FROM class_sessions WHERE subject_id = ?)',
          [id],
        );
      }
      await txn.delete('subjects', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<List<AcademicTask>> getTasks() async =>
      (await (await database).query('tasks', orderBy: 'due_date ASC')).map(AcademicTask.fromMap).toList();

  Future<AcademicTask> saveTask(AcademicTask item) async {
    final db = await database;
    if (item.id == null) return item.copyWith(id: await db.insert('tasks', item.toMap()));
    await db.update('tasks', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item;
  }

  Future<void> deleteTask(int id) async =>
      (await database).delete('tasks', where: 'id = ?', whereArgs: [id]);

  Future<List<Grade>> getGrades() async =>
      (await (await database).query('grades', orderBy: 'date DESC')).map(Grade.fromMap).toList();

  Future<Grade> saveGrade(Grade item) async {
    final db = await database;
    if (item.id == null) {
      final id = await db.insert('grades', item.toMap());
      return Grade(id: id, subjectId: item.subjectId, title: item.title, value: item.value, weight: item.weight, date: item.date);
    }
    await db.update('grades', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item;
  }

  Future<void> deleteGrade(int id) async =>
      (await database).delete('grades', where: 'id = ?', whereArgs: [id]);

  Future<List<ScheduleEntry>> getSchedules() async =>
      (await (await database).query('schedules', orderBy: 'day ASC, start_time ASC')).map(ScheduleEntry.fromMap).toList();

  Future<ScheduleEntry> saveSchedule(ScheduleEntry item) async {
    final db = await database;
    if (item.id == null) {
      final id = await db.insert('schedules', item.toMap());
      return item.copyWith(id: id);
    }
    await db.update('schedules', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item;
  }

  Future<void> deleteSchedule(int id) async =>
      (await database).delete('schedules', where: 'id = ?', whereArgs: [id]);

  Future<List<ClassSession>> getClassSessions() async =>
      (await (await database).query('class_sessions', orderBy: 'date ASC, start_time ASC')).map(ClassSession.fromMap).toList();

  Future<ClassSession> saveClassSession(ClassSession item) async {
    final db = await database;
    if (item.id == null) {
      final id = await db.insert('class_sessions', item.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
      if (id == 0 && item.scheduleId != null) {
        final rows = await db.query(
          'class_sessions',
          where: 'schedule_id = ? AND date = ?',
          whereArgs: [item.scheduleId, _dateKey(item.date)],
          limit: 1,
        );
        if (rows.isNotEmpty) return ClassSession.fromMap(rows.first);
      }
      return item.copyWith(id: id);
    }
    await db.update('class_sessions', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item;
  }

  Future<void> deleteClassSession(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final table in const ['tasks', 'notes', 'materials']) {
        await txn.update(table, {'session_id': null}, where: 'session_id = ?', whereArgs: [id]);
      }
      await txn.delete('class_sessions', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> deleteFutureSessionsForSchedule(int scheduleId, DateTime from) async {
    final date = _dateKey(from);
    final time = _timeKey(from);
    await (await database).delete(
      'class_sessions',
      where: 'schedule_id = ? AND status = ? AND (date > ? OR (date = ? AND start_time > ?))',
      whereArgs: [scheduleId, AttendanceStatus.pending.index, date, date, time],
    );
  }

  Future<List<AcademicCalendarEvent>> getCalendarEvents() async =>
      (await (await database).query('academic_calendar', orderBy: 'date ASC')).map(AcademicCalendarEvent.fromMap).toList();

  Future<AcademicCalendarEvent> saveCalendarEvent(AcademicCalendarEvent item) async {
    final db = await database;
    if (item.id == null) return item.copyWith(id: await db.insert('academic_calendar', item.toMap()));
    await db.update('academic_calendar', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item;
  }

  Future<void> deleteCalendarEvent(int id) async =>
      (await database).delete('academic_calendar', where: 'id = ?', whereArgs: [id]);

  Future<List<AcademicNote>> getNotes() async =>
      (await (await database).query('notes', orderBy: 'pinned DESC, created_at DESC')).map(AcademicNote.fromMap).toList();

  Future<AcademicNote> saveNote(AcademicNote item) async {
    final db = await database;
    if (item.id == null) {
      final id = await db.insert('notes', item.toMap());
      return AcademicNote(
        id: id,
        subjectId: item.subjectId,
        title: item.title,
        content: item.content,
        link: item.link,
        tags: item.tags,
        pinned: item.pinned,
        createdAt: item.createdAt,
        sessionId: item.sessionId,
      );
    }
    await db.update('notes', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item;
  }

  Future<void> deleteNote(int id) async =>
      (await database).delete('notes', where: 'id = ?', whereArgs: [id]);

  Future<List<MaterialResource>> getMaterials() async =>
      (await (await database).query('materials', orderBy: 'created_at DESC')).map(MaterialResource.fromMap).toList();

  Future<MaterialResource> saveMaterial(MaterialResource item) async {
    final db = await database;
    if (item.id == null) {
      final id = await db.insert('materials', item.toMap());
      return MaterialResource(
        id: id,
        subjectId: item.subjectId,
        title: item.title,
        url: item.url,
        description: item.description,
        kind: item.kind,
        createdAt: item.createdAt,
        sessionId: item.sessionId,
      );
    }
    await db.update('materials', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item;
  }

  Future<void> deleteMaterial(int id) async =>
      (await database).delete('materials', where: 'id = ?', whereArgs: [id]);

  Future<void> clearAcademicData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('grades');
      await txn.delete('materials');
      await txn.delete('notes');
      await txn.delete('tasks');
      await txn.delete('class_sessions');
      await txn.delete('academic_calendar');
      await txn.delete('schedules');
      await txn.delete('subjects');
    });
  }

  Future<void> resetEverything() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('grades');
      await txn.delete('materials');
      await txn.delete('notes');
      await txn.delete('tasks');
      await txn.delete('class_sessions');
      await txn.delete('academic_calendar');
      await txn.delete('schedules');
      await txn.delete('subjects');
      await txn.delete('settings');
    });
  }
}

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _timeKey(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
