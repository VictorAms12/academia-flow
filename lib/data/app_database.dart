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
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
    return _database!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE subjects(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        professor TEXT NOT NULL DEFAULT '',
        room TEXT NOT NULL DEFAULT '',
        total_classes INTEGER NOT NULL DEFAULT 0,
        absences INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE tasks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        subject_id INTEGER,
        due_date TEXT NOT NULL,
        priority INTEGER NOT NULL DEFAULT 1,
        status INTEGER NOT NULL DEFAULT 0,
        description TEXT NOT NULL DEFAULT '',
        checklist TEXT NOT NULL DEFAULT '[]',
        completed_steps TEXT NOT NULL DEFAULT '[]',
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE SET NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE grades(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        value REAL NOT NULL,
        weight REAL NOT NULL DEFAULT 1,
        date TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE schedules(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL,
        day INTEGER NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        room TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER,
        title TEXT NOT NULL,
        content TEXT NOT NULL DEFAULT '',
        link TEXT NOT NULL DEFAULT '',
        created_at TEXT NOT NULL,
        FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE SET NULL
      )
    ''');
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Subject>> getSubjects() async {
    final db = await database;
    final rows = await db.query('subjects', orderBy: 'name COLLATE NOCASE');
    return rows.map(Subject.fromMap).toList();
  }

  Future<Subject> saveSubject(Subject item) async {
    final db = await database;
    if (item.id == null) {
      final id = await db.insert('subjects', item.toMap());
      return item.copyWith(id: id);
    }
    await db.update('subjects', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item;
  }

  Future<void> deleteSubject(int id) async {
    final db = await database;
    await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AcademicTask>> getTasks() async {
    final db = await database;
    final rows = await db.query('tasks', orderBy: 'due_date ASC');
    return rows.map(AcademicTask.fromMap).toList();
  }

  Future<AcademicTask> saveTask(AcademicTask item) async {
    final db = await database;
    if (item.id == null) {
      final id = await db.insert('tasks', item.toMap());
      return item.copyWith(id: id);
    }
    await db.update('tasks', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item;
  }

  Future<void> deleteTask(int id) async {
    final db = await database;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Grade>> getGrades() async {
    final db = await database;
    final rows = await db.query('grades', orderBy: 'date DESC');
    return rows.map(Grade.fromMap).toList();
  }

  Future<Grade> saveGrade(Grade item) async {
    final db = await database;
    if (item.id == null) {
      final id = await db.insert('grades', item.toMap());
      return Grade(id: id, subjectId: item.subjectId, title: item.title, value: item.value, weight: item.weight, date: item.date);
    }
    await db.update('grades', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item;
  }

  Future<void> deleteGrade(int id) async {
    final db = await database;
    await db.delete('grades', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ScheduleEntry>> getSchedules() async {
    final db = await database;
    final rows = await db.query('schedules', orderBy: 'day ASC, start_time ASC');
    return rows.map(ScheduleEntry.fromMap).toList();
  }

  Future<ScheduleEntry> saveSchedule(ScheduleEntry item) async {
    final db = await database;
    if (item.id == null) {
      final id = await db.insert('schedules', item.toMap());
      return ScheduleEntry(id: id, subjectId: item.subjectId, day: item.day, start: item.start, end: item.end, room: item.room);
    }
    await db.update('schedules', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item;
  }

  Future<void> deleteSchedule(int id) async {
    final db = await database;
    await db.delete('schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<AcademicNote>> getNotes() async {
    final db = await database;
    final rows = await db.query('notes', orderBy: 'created_at DESC');
    return rows.map(AcademicNote.fromMap).toList();
  }

  Future<AcademicNote> saveNote(AcademicNote item) async {
    final db = await database;
    if (item.id == null) {
      final id = await db.insert('notes', item.toMap());
      return AcademicNote(id: id, subjectId: item.subjectId, title: item.title, content: item.content, link: item.link, createdAt: item.createdAt);
    }
    await db.update('notes', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
    return item;
  }

  Future<void> deleteNote(int id) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearAcademicData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('grades');
      await txn.delete('schedules');
      await txn.delete('notes');
      await txn.delete('tasks');
      await txn.delete('subjects');
    });
  }

  Future<void> resetEverything() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('grades');
      await txn.delete('schedules');
      await txn.delete('notes');
      await txn.delete('tasks');
      await txn.delete('subjects');
      await txn.delete('settings');
    });
  }
}
