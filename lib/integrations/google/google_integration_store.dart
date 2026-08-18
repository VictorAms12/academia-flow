import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../data/app_database.dart';
import 'google_models.dart';

class GoogleIntegrationStore {
  GoogleIntegrationStore._();
  static final GoogleIntegrationStore instance = GoogleIntegrationStore._();
  final AppDatabase _db = AppDatabase.instance;
  Future<void>? _schemaFuture;

  Future<void> ensureSchema() {
    final existing = _schemaFuture;
    if (existing != null) return existing;
    final future = _createSchema();
    _schemaFuture = future;
    return future.catchError((Object error) {
      _schemaFuture = null;
      throw error;
    });
  }

  Future<void> _createSchema() async {
    final db = await _db.database;
    await db.execute('''CREATE TABLE IF NOT EXISTS google_account(
      singleton_id INTEGER PRIMARY KEY CHECK(singleton_id = 1),
      google_user_id TEXT NOT NULL,
      email TEXT NOT NULL,
      display_name TEXT NOT NULL DEFAULT '',
      photo_url TEXT NOT NULL DEFAULT '',
      classroom_connected INTEGER NOT NULL DEFAULT 0,
      last_sync_at TEXT
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS classroom_course_links(
      google_user_id TEXT NOT NULL,
      classroom_course_id TEXT NOT NULL,
      subject_id INTEGER NOT NULL,
      classroom_name TEXT NOT NULL DEFAULT '',
      course_state TEXT NOT NULL DEFAULT '',
      alternate_link TEXT NOT NULL DEFAULT '',
      last_synced_at TEXT,
      FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE CASCADE,
      PRIMARY KEY(google_user_id, classroom_course_id)
    )''');
    await db.execute('''CREATE TABLE IF NOT EXISTS classroom_task_links(
      google_user_id TEXT NOT NULL,
      classroom_course_id TEXT NOT NULL,
      classroom_coursework_id TEXT NOT NULL,
      task_id INTEGER NOT NULL,
      submission_state TEXT NOT NULL DEFAULT '',
      alternate_link TEXT NOT NULL DEFAULT '',
      updated_at TEXT,
      PRIMARY KEY(google_user_id, classroom_course_id, classroom_coursework_id),
      FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_classroom_task_id ON classroom_task_links(task_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_classroom_course_user ON classroom_course_links(google_user_id, classroom_name)');
  }

  Future<GoogleAccountProfile?> getAccount() async {
    await ensureSchema();
    final db = await _db.database;
    final rows = await db.query('google_account', where: 'singleton_id = 1', limit: 1);
    return rows.isEmpty ? null : GoogleAccountProfile.fromMap(rows.first);
  }

  Future<void> saveAccount(GoogleAccountProfile account) async {
    await ensureSchema();
    final db = await _db.database;
    await db.insert('google_account', account.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearAccount() async {
    await ensureSchema();
    final db = await _db.database;
    await db.delete('google_account');
  }

  Future<List<ClassroomCourseLink>> getCourseLinks(String googleUserId) async {
    await ensureSchema();
    final db = await _db.database;
    return (await db.query(
      'classroom_course_links',
      where: 'google_user_id = ?',
      whereArgs: [googleUserId],
      orderBy: 'classroom_name COLLATE NOCASE',
    ))
        .map(ClassroomCourseLink.fromMap)
        .toList();
  }

  Future<void> saveCourseLink(ClassroomCourseLink link) async {
    await ensureSchema();
    final db = await _db.database;
    await db.insert('classroom_course_links', link.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCourseLink(String googleUserId, String courseId) async {
    await ensureSchema();
    final db = await _db.database;
    await db.delete(
      'classroom_course_links',
      where: 'google_user_id = ? AND classroom_course_id = ?',
      whereArgs: [googleUserId, courseId],
    );
  }

  Future<void> deleteTaskLinksForCourse(String googleUserId, String courseId) async {
    await ensureSchema();
    final db = await _db.database;
    await db.delete(
      'classroom_task_links',
      where: 'google_user_id = ? AND classroom_course_id = ?',
      whereArgs: [googleUserId, courseId],
    );
  }

  Future<List<ClassroomTaskLink>> getTaskLinks(String googleUserId) async {
    await ensureSchema();
    final db = await _db.database;
    return (await db.query(
      'classroom_task_links',
      where: 'google_user_id = ?',
      whereArgs: [googleUserId],
      orderBy: 'updated_at DESC',
    ))
        .map(ClassroomTaskLink.fromMap)
        .toList();
  }

  Future<void> saveTaskLink(ClassroomTaskLink link) async {
    await ensureSchema();
    final db = await _db.database;
    await db.insert('classroom_task_links', link.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearAll() async {
    await ensureSchema();
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete('classroom_task_links');
      await txn.delete('classroom_course_links');
      await txn.delete('google_account');
    });
  }
}
