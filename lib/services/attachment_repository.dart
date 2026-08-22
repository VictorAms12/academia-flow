import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../models/attachment.dart';

class AttachmentRepository {
  AttachmentRepository._();

  static final AttachmentRepository instance = AttachmentRepository._();

  final ImagePicker _imagePicker = ImagePicker();
  bool _initialized = false;
  Directory? _root;

  Future<Database> get _db => AppDatabase.instance.database;

  Future<void> initialize() async {
    if (_initialized) return;
    final db = await _db;
    await db.execute('''CREATE TABLE IF NOT EXISTS attachments(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      subject_id INTEGER,
      session_id INTEGER,
      note_id INTEGER,
      material_id INTEGER,
      task_id INTEGER,
      title TEXT NOT NULL,
      file_name TEXT NOT NULL,
      stored_path TEXT NOT NULL UNIQUE,
      kind INTEGER NOT NULL DEFAULT 4,
      mime_type TEXT NOT NULL DEFAULT '',
      size_bytes INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      FOREIGN KEY(subject_id) REFERENCES subjects(id) ON DELETE SET NULL,
      FOREIGN KEY(session_id) REFERENCES class_sessions(id) ON DELETE CASCADE,
      FOREIGN KEY(note_id) REFERENCES notes(id) ON DELETE CASCADE,
      FOREIGN KEY(material_id) REFERENCES materials(id) ON DELETE CASCADE,
      FOREIGN KEY(task_id) REFERENCES tasks(id) ON DELETE CASCADE,
      CHECK (
        (session_id IS NOT NULL) +
        (note_id IS NOT NULL) +
        (material_id IS NOT NULL) +
        (task_id IS NOT NULL) = 1
      )
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_attachments_session ON attachments(session_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_attachments_note ON attachments(note_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_attachments_material ON attachments(material_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_attachments_task ON attachments(task_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_attachments_subject ON attachments(subject_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_attachments_created ON attachments(created_at)');

    final documents = await getApplicationDocumentsDirectory();
    _root = Directory(p.join(documents.path, 'academia_flow', 'attachments'));
    if (!await _root!.exists()) await _root!.create(recursive: true);
    _initialized = true;
    await pruneOrphanedFiles();
  }

  Future<Directory> get root async {
    await initialize();
    return _root!;
  }

  Future<List<AcademicAttachment>> allAttachments({bool prune = true}) async {
    await initialize();
    if (prune) await pruneOrphanedFiles();
    final rows = await (await _db).query('attachments', orderBy: 'created_at DESC');
    return rows.map(AcademicAttachment.fromMap).toList();
  }

  Future<List<AcademicAttachment>> forTarget(AttachmentTarget target) async {
    await initialize();
    final (column, id) = _targetColumn(target);
    final rows = await (await _db).query(
      'attachments',
      where: '$column = ?',
      whereArgs: [id],
      orderBy: 'created_at DESC',
    );
    return rows.map(AcademicAttachment.fromMap).toList();
  }

  Future<int> countForTarget(AttachmentTarget target) async {
    await initialize();
    final (column, id) = _targetColumn(target);
    final rows = await (await _db).rawQuery('SELECT COUNT(*) AS total FROM attachments WHERE $column = ?', [id]);
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<AcademicAttachment>> pickFiles({
    required AttachmentTarget target,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return const [];
    final added = <AcademicAttachment>[];
    for (final picked in result.files) {
      final sourcePath = picked.path;
      if (sourcePath == null || sourcePath.trim().isEmpty) continue;
      added.add(await _importFile(File(sourcePath), target: target, preferredName: picked.name));
    }
    return added;
  }

  Future<List<AcademicAttachment>> pickImages({
    required AttachmentTarget target,
  }) async {
    final images = await _imagePicker.pickMultiImage(
      imageQuality: 88,
      maxWidth: 2200,
    );
    if (images.isEmpty) return const [];
    final added = <AcademicAttachment>[];
    for (final image in images) {
      added.add(await _importFile(File(image.path), target: target, preferredName: image.name));
    }
    return added;
  }

  Future<AcademicAttachment?> takePhoto({
    required AttachmentTarget target,
  }) async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
      maxWidth: 2200,
    );
    if (image == null) return null;
    return _importFile(File(image.path), target: target, preferredName: image.name);
  }

  Future<AcademicAttachment> _importFile(
    File source, {
    required AttachmentTarget target,
    String? preferredName,
  }) async {
    await initialize();
    if (!await source.exists()) throw StateError('O arquivo selecionado não está mais disponível.');

    final originalName = _safeName(preferredName?.trim().isNotEmpty == true ? preferredName!.trim() : p.basename(source.path));
    final uniqueName = '${DateTime.now().microsecondsSinceEpoch}_$originalName';
    final destination = File(p.join(_root!.path, uniqueName));
    await source.copy(destination.path);
    final bytes = await destination.length();
    final kind = attachmentKindForName(originalName);

    final item = AcademicAttachment(
      targetType: target.type,
      targetId: target.id,
      subjectId: target.subjectId,
      title: p.basenameWithoutExtension(originalName).trim().isEmpty ? originalName : p.basenameWithoutExtension(originalName),
      fileName: originalName,
      storedPath: uniqueName,
      kind: kind,
      mimeType: _mimeForName(originalName),
      sizeBytes: bytes,
      createdAt: DateTime.now(),
    );

    try {
      final id = await (await _db).insert('attachments', item.toMap());
      return item.copyWith(id: id);
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      rethrow;
    }
  }

  Future<AcademicAttachment> rename(AcademicAttachment item, String title) async {
    if (item.id == null) return item;
    final clean = title.trim();
    if (clean.isEmpty) return item;
    await initialize();
    await (await _db).update('attachments', {'title': clean}, where: 'id = ?', whereArgs: [item.id]);
    return item.copyWith(title: clean);
  }

  Future<void> delete(AcademicAttachment item) async {
    await initialize();
    if (item.id != null) {
      await (await _db).delete('attachments', where: 'id = ?', whereArgs: [item.id]);
    }
    final file = await resolveFile(item);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        // A limpeza de órfãos tentará novamente depois.
      }
    }
  }

  Future<File> resolveFile(AcademicAttachment item) async {
    final directory = await root;
    return File(p.join(directory.path, item.storedPath));
  }

  Future<bool> exists(AcademicAttachment item) async => (await resolveFile(item)).exists();

  Future<void> openExternally(AcademicAttachment item) async {
    final file = await resolveFile(item);
    if (!await file.exists()) throw StateError('O arquivo não foi encontrado no armazenamento do aplicativo.');
    await OpenFilex.open(file.path);
  }

  Future<void> pruneOrphanedFiles() async {
    if (!_initialized || _root == null || !await _root!.exists()) return;
    final rows = await (await _db).query('attachments', columns: ['stored_path']);
    final known = rows.map((row) => '${row['stored_path']}').toSet();
    await for (final entity in _root!.list(followLinks: false)) {
      if (entity is! File) continue;
      if (!known.contains(p.basename(entity.path))) {
        try {
          await entity.delete();
        } catch (_) {
          // Não interrompe o app por falha de limpeza.
        }
      }
    }
  }

  (String, int) _targetColumn(AttachmentTarget target) => switch (target.type) {
        AttachmentTargetType.classSession => ('session_id', target.id),
        AttachmentTargetType.note => ('note_id', target.id),
        AttachmentTargetType.material => ('material_id', target.id),
        AttachmentTargetType.task => ('task_id', target.id),
      };

  String _safeName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? 'anexo' : cleaned;
  }

  String _mimeForName(String name) {
    final ext = p.extension(name).toLowerCase();
    return switch (ext) {
      '.jpg' || '.jpeg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      '.heic' || '.heif' => 'image/heic',
      '.pdf' => 'application/pdf',
      '.txt' => 'text/plain',
      '.csv' => 'text/csv',
      '.md' => 'text/markdown',
      '.zip' => 'application/zip',
      _ => '',
    };
  }
}
