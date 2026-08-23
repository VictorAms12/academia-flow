import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../data/app_database.dart';
import '../models/backup_models.dart';
import 'attachment_repository.dart';

class BackupService {
  BackupService._();

  static final BackupService instance = BackupService._();

  static const int formatVersion = 1;
  static const String appVersion = '2.6.5+24';

  static const List<String> _backupTables = [
    'settings',
    'subjects',
    'schedules',
    'class_sessions',
    'academic_calendar',
    'tasks',
    'grades',
    'notes',
    'materials',
    'attachments',
  ];

  static const List<String> _deleteOrder = [
    'attachments',
    'grades',
    'materials',
    'notes',
    'tasks',
    'academic_calendar',
    'class_sessions',
    'schedules',
    'subjects',
    'settings',
  ];

  static const List<String> _insertOrder = [
    'settings',
    'subjects',
    'schedules',
    'class_sessions',
    'academic_calendar',
    'tasks',
    'grades',
    'notes',
    'materials',
    'attachments',
  ];

  final AppDatabase _database = AppDatabase.instance;
  final AttachmentRepository _attachments = AttachmentRepository.instance;

  Future<Directory> get backupDirectory async {
    final documents = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(documents.path, 'academia_flow', 'backups'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  Future<File> createInternalBackup({BackupKind kind = BackupKind.manual}) async {
    await _attachments.initialize();
    final snapshot = await _captureSnapshot();
    final now = DateTime.now();
    final directory = await backupDirectory;
    final destination = File(p.join(directory.path, _backupFileName(now, kind)));
    if (await destination.exists()) await destination.delete();

    final work = await Directory.systemTemp.createTemp('academia_flow_backup_');
    try {
      final payload = <String, Object?>{
        'format_version': formatVersion,
        'tables': snapshot.tables,
      };
      final dataBytes = utf8.encode(jsonEncode(payload));
      final dataSha = sha256.convert(dataBytes).toString();
      final dataFile = File(p.join(work.path, 'data.json'));
      await dataFile.writeAsBytes(dataBytes, flush: true);

      final attachmentDigests = <String, String>{};
      final root = await _attachments.root;
      var attachmentBytes = 0;
      for (final row in snapshot.tables['attachments'] ?? const <Map<String, Object?>>[]) {
        final storedPath = '${row['stored_path'] ?? ''}';
        if (!_safeStoredPath(storedPath)) continue;
        final file = File(p.join(root.path, storedPath));
        if (!await file.exists()) continue;
        attachmentBytes += await file.length();
        attachmentDigests[storedPath] = await _sha256File(file);
      }

      final counts = <String, int>{
        for (final entry in snapshot.tables.entries) entry.key: entry.value.length,
      };
      final manifest = <String, Object?>{
        'format_version': formatVersion,
        'app_version': appVersion,
        'created_at': now.toUtc().toIso8601String(),
        'kind': kind.name,
        'counts': counts,
        'attachment_bytes': attachmentBytes,
        'missing_attachments': snapshot.missingAttachments,
        'data_sha256': dataSha,
        'attachment_sha256': attachmentDigests,
        'google_credentials_included': false,
      };
      final manifestFile = File(p.join(work.path, 'manifest.json'));
      await manifestFile.writeAsString(jsonEncode(manifest), flush: true);

      final encoder = ZipFileEncoder();
      encoder.create(destination.path);
      await encoder.addFile(manifestFile, 'manifest.json');
      await encoder.addFile(dataFile, 'data.json');
      for (final row in snapshot.tables['attachments'] ?? const <Map<String, Object?>>[]) {
        final storedPath = '${row['stored_path'] ?? ''}';
        if (!_safeStoredPath(storedPath)) continue;
        final file = File(p.join(root.path, storedPath));
        if (await file.exists()) {
          await encoder.addFile(file, 'attachments/$storedPath');
        }
      }
      await encoder.close();
      await _pruneInternalBackups();
      return destination;
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      rethrow;
    } finally {
      if (await work.exists()) await work.delete(recursive: true);
    }
  }

  Future<String?> createAndExportBackup() async {
    final backup = await createInternalBackup(kind: BackupKind.manual);
    return exportBackupFile(backup.path);
  }

  Future<String?> exportBackupFile(String sourcePath) async {
    final source = File(sourcePath);
    if (!await source.exists()) throw StateError('O arquivo de backup não foi encontrado.');
    final selectedDirectory = await FilePicker.getDirectoryPath(
      dialogTitle: 'Escolha onde salvar o backup',
    );
    if (selectedDirectory == null || selectedDirectory.trim().isEmpty) return null;
    final target = await _uniqueDestination(Directory(selectedDirectory), p.basename(source.path));
    await source.copy(target.path);
    return target.path;
  }

  Future<String?> pickBackupFile() async {
    final picked = await FilePicker.pickFile(
      dialogTitle: 'Selecione um backup do Academia Flow',
      type: FileType.custom,
      allowedExtensions: const ['afbackup'],
    );
    if (picked == null) return null;
    final path = picked.path;
    if (path != null && path.trim().isNotEmpty && await File(path).exists()) return path;

    final bytes = await picked.readAsBytes();
    final temp = await getTemporaryDirectory();
    final target = File(p.join(temp.path, 'academia_flow_restore_${DateTime.now().microsecondsSinceEpoch}.afbackup'));
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  Future<BackupPreview> inspect(String sourcePath) async {
    final file = File(sourcePath);
    if (!await file.exists()) throw StateError('Backup não encontrado.');
    final input = InputFileStream(file.path);
    try {
      final archive = ZipDecoder().decodeStream(input, verify: true);
      final manifestBytes = _entryBytes(archive, 'manifest.json');
      final dataBytes = _entryBytes(archive, 'data.json');
      final manifest = _decodeObject(manifestBytes, 'manifesto');
      _validateManifest(manifest);
      final expectedSha = '${manifest['data_sha256'] ?? ''}';
      final actualSha = sha256.convert(dataBytes).toString();
      if (expectedSha.isEmpty || expectedSha != actualSha) {
        throw const FormatException('O conteúdo do backup não passou na verificação de integridade.');
      }
      _validatePayload(_decodeObject(dataBytes, 'dados'));
      return _previewFromManifest(
        sourcePath: file.path,
        archiveBytes: await file.length(),
        manifest: manifest,
        integrityValid: true,
      );
    } finally {
      input.closeSync();
    }
  }

  Future<BackupPreview> restore(String sourcePath) async {
    final preview = await inspect(sourcePath);
    if (preview.formatVersion > formatVersion) {
      throw StateError('Este backup foi criado por uma versão mais nova do Academia Flow. Atualize o aplicativo antes de restaurar.');
    }

    await createInternalBackup(kind: BackupKind.safety);
    await _attachments.initialize();

    final input = InputFileStream(sourcePath);
    final documents = await getApplicationDocumentsDirectory();
    final appRoot = Directory(p.join(documents.path, 'academia_flow'));
    if (!await appRoot.exists()) await appRoot.create(recursive: true);
    final restoreRoot = Directory(p.join(appRoot.path, '.restore_${DateTime.now().microsecondsSinceEpoch}'));
    final stagedAttachments = Directory(p.join(restoreRoot.path, 'attachments'));
    await stagedAttachments.create(recursive: true);

    Directory? previousAttachments;
    var swapped = false;
    try {
      final archive = ZipDecoder().decodeStream(input, verify: true);
      final manifest = _decodeObject(_entryBytes(archive, 'manifest.json'), 'manifesto');
      _validateManifest(manifest);
      final dataBytes = _entryBytes(archive, 'data.json');
      final expectedDataSha = '${manifest['data_sha256'] ?? ''}';
      if (sha256.convert(dataBytes).toString() != expectedDataSha) {
        throw const FormatException('O arquivo de dados do backup está corrompido.');
      }
      final payload = _decodeObject(dataBytes, 'dados');
      final tables = _tablesFromPayload(payload);
      final attachmentHashes = _stringMap(manifest['attachment_sha256']);

      for (final entry in archive) {
        if (!entry.isFile || !entry.name.startsWith('attachments/')) continue;
        final relative = entry.name.substring('attachments/'.length);
        if (!_safeStoredPath(relative)) {
          throw const FormatException('O backup contém um caminho de anexo inválido.');
        }
        final output = OutputFileStream(p.join(stagedAttachments.path, relative));
        entry.writeContent(output);
        output.closeSync();
      }

      for (final row in tables['attachments'] ?? const <Map<String, Object?>>[]) {
        final storedPath = '${row['stored_path'] ?? ''}';
        if (!_safeStoredPath(storedPath)) throw const FormatException('Metadados de anexo inválidos.');
        final restored = File(p.join(stagedAttachments.path, storedPath));
        if (!await restored.exists()) throw FormatException('Anexo ausente no backup: $storedPath');
        final expected = attachmentHashes[storedPath];
        if (expected == null || expected.isEmpty || await _sha256File(restored) != expected) {
          throw FormatException('Falha de integridade no anexo: $storedPath');
        }
      }

      final attachmentRoot = await _attachments.root;
      previousAttachments = Directory(p.join(appRoot.path, '.attachments_before_restore_${DateTime.now().microsecondsSinceEpoch}'));
      if (await previousAttachments.exists()) await previousAttachments.delete(recursive: true);
      if (await attachmentRoot.exists()) await attachmentRoot.rename(previousAttachments.path);
      await stagedAttachments.rename(attachmentRoot.path);
      swapped = true;

      try {
        await _restoreTables(tables);
      } catch (_) {
        final currentRoot = Directory(attachmentRoot.path);
        if (await currentRoot.exists()) await currentRoot.delete(recursive: true);
        if (previousAttachments != null && await previousAttachments.exists()) {
          await previousAttachments.rename(attachmentRoot.path);
        }
        swapped = false;
        rethrow;
      }

      if (previousAttachments != null && await previousAttachments.exists()) {
        await previousAttachments.delete(recursive: true);
      }
      return preview;
    } finally {
      input.closeSync();
      if (await restoreRoot.exists()) await restoreRoot.delete(recursive: true);
      if (!swapped && previousAttachments != null && await previousAttachments.exists()) {
        final root = await _attachments.root;
        if (!await root.exists()) await previousAttachments.rename(root.path);
      }
    }
  }

  Future<List<BackupPreview>> internalBackups() async {
    final directory = await backupDirectory;
    final files = await directory
        .list(followLinks: false)
        .where((entity) => entity is File && entity.path.toLowerCase().endsWith('.afbackup'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    final previews = <BackupPreview>[];
    for (final file in files) {
      try {
        previews.add(await inspect(file.path));
      } catch (_) {
        // Arquivos inválidos não impedem o usuário de acessar backups válidos.
      }
    }
    return previews;
  }

  Future<void> deleteInternalBackup(BackupPreview preview) async {
    final directory = await backupDirectory;
    final source = File(preview.sourcePath);
    if (!p.isWithin(directory.path, source.path)) {
      throw StateError('Só é possível excluir backups internos pelo aplicativo.');
    }
    if (await source.exists()) await source.delete();
  }

  Future<bool> get automaticBackupEnabled async => (await _database.getSetting('backup_auto_enabled') ?? 'false') == 'true';

  Future<int> get automaticBackupIntervalDays async {
    final value = int.tryParse(await _database.getSetting('backup_auto_interval_days') ?? '') ?? 7;
    return value.clamp(1, 30).toInt();
  }

  Future<void> setAutomaticBackup({required bool enabled, int intervalDays = 7}) async {
    await _database.setSetting('backup_auto_enabled', '$enabled');
    await _database.setSetting('backup_auto_interval_days', '${intervalDays.clamp(1, 30)}');
  }

  Future<void> maybeCreateAutomaticBackup() async {
    if (!await automaticBackupEnabled) return;
    final interval = await automaticBackupIntervalDays;
    final last = DateTime.tryParse(await _database.getSetting('backup_last_auto_at') ?? '');
    if (last != null && DateTime.now().difference(last).inDays < interval) return;
    final db = await _database.database;
    final hasAcademicData = await _hasAnyAcademicData(db);
    if (!hasAcademicData) return;
    await createInternalBackup(kind: BackupKind.automatic);
    await _database.setSetting('backup_last_auto_at', DateTime.now().toUtc().toIso8601String());
  }

  Future<_BackupSnapshot> _captureSnapshot() async {
    final db = await _database.database;
    final tables = <String, List<Map<String, Object?>>>{};
    for (final table in _backupTables) {
      if (!await _tableExists(db, table)) continue;
      final rows = await db.query(table);
      if (table == 'settings') {
        rows.removeWhere((row) => row['key'] == 'backup_last_auto_at');
      }
      tables[table] = rows.map((row) => Map<String, Object?>.from(row)).toList();
    }

    var missingAttachments = 0;
    final root = await _attachments.root;
    final validAttachments = <Map<String, Object?>>[];
    for (final row in tables['attachments'] ?? const <Map<String, Object?>>[]) {
      final storedPath = '${row['stored_path'] ?? ''}';
      if (!_safeStoredPath(storedPath) || !await File(p.join(root.path, storedPath)).exists()) {
        missingAttachments++;
        continue;
      }
      validAttachments.add(row);
    }
    if (tables.containsKey('attachments')) tables['attachments'] = validAttachments;
    return _BackupSnapshot(tables: tables, missingAttachments: missingAttachments);
  }

  Future<void> _restoreTables(Map<String, List<Map<String, Object?>>> tables) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.execute('PRAGMA defer_foreign_keys = ON');
      for (final table in _deleteOrder) {
        if (await _tableExists(txn, table)) await txn.delete(table);
      }

      final sessionMakeupLinks = <int, int?>{};
      for (final table in _insertOrder) {
        final rows = tables[table] ?? const <Map<String, Object?>>[];
        if (rows.isEmpty || !await _tableExists(txn, table)) continue;
        for (final original in rows) {
          final row = Map<String, Object?>.from(original);
          if (table == 'class_sessions') {
            final id = row['id'] as int?;
            if (id != null) sessionMakeupLinks[id] = row['makeup_for_session_id'] as int?;
            row['makeup_for_session_id'] = null;
          }
          await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.abort);
        }
      }

      for (final entry in sessionMakeupLinks.entries) {
        if (entry.value == null) continue;
        await txn.update(
          'class_sessions',
          {'makeup_for_session_id': entry.value},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
    });
  }

  Future<void> _pruneInternalBackups() async {
    final directory = await backupDirectory;
    final files = await directory
        .list(followLinks: false)
        .where((entity) => entity is File && entity.path.toLowerCase().endsWith('.afbackup'))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    final byKind = <BackupKind, List<File>>{
      BackupKind.manual: [],
      BackupKind.automatic: [],
      BackupKind.safety: [],
    };
    for (final file in files) {
      final lower = p.basename(file.path).toLowerCase();
      final kind = lower.contains('_automatic_')
          ? BackupKind.automatic
          : lower.contains('_safety_')
              ? BackupKind.safety
              : BackupKind.manual;
      byKind[kind]!.add(file);
    }

    const limits = {
      BackupKind.manual: 3,
      BackupKind.automatic: 5,
      BackupKind.safety: 3,
    };
    for (final entry in byKind.entries) {
      final limit = limits[entry.key]!;
      for (final file in entry.value.skip(limit)) {
        try {
          await file.delete();
        } catch (_) {}
      }
    }
  }

  BackupPreview _previewFromManifest({
    required String sourcePath,
    required int archiveBytes,
    required Map<String, dynamic> manifest,
    required bool integrityValid,
  }) {
    final rawCounts = manifest['counts'];
    final counts = <String, int>{};
    if (rawCounts is Map) {
      for (final entry in rawCounts.entries) {
        counts['${entry.key}'] = (entry.value as num?)?.toInt() ?? 0;
      }
    }
    return BackupPreview(
      sourcePath: sourcePath,
      fileName: p.basename(sourcePath),
      formatVersion: (manifest['format_version'] as num?)?.toInt() ?? 0,
      appVersion: '${manifest['app_version'] ?? 'desconhecida'}',
      createdAt: DateTime.tryParse('${manifest['created_at'] ?? ''}')?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0),
      kind: backupKindFromName('${manifest['kind'] ?? ''}'),
      counts: counts,
      attachmentBytes: (manifest['attachment_bytes'] as num?)?.toInt() ?? 0,
      archiveBytes: archiveBytes,
      dataSha256: '${manifest['data_sha256'] ?? ''}',
      missingAttachments: (manifest['missing_attachments'] as num?)?.toInt() ?? 0,
      integrityValid: integrityValid,
    );
  }

  void _validateManifest(Map<String, dynamic> manifest) {
    final version = (manifest['format_version'] as num?)?.toInt();
    if (version == null || version <= 0) throw const FormatException('Formato de backup inválido.');
    if (version > formatVersion) {
      throw StateError('Backup incompatível com esta versão do Academia Flow.');
    }
    if ('${manifest['data_sha256'] ?? ''}'.length != 64) {
      throw const FormatException('Manifesto de integridade inválido.');
    }
  }

  void _validatePayload(Map<String, dynamic> payload) {
    final version = (payload['format_version'] as num?)?.toInt();
    if (version != formatVersion) throw const FormatException('Versão dos dados de backup inválida.');
    if (payload['tables'] is! Map) throw const FormatException('Backup sem tabelas de dados.');
  }

  Map<String, List<Map<String, Object?>>> _tablesFromPayload(Map<String, dynamic> payload) {
    _validatePayload(payload);
    final raw = payload['tables'] as Map;
    final result = <String, List<Map<String, Object?>>>{};
    for (final table in _backupTables) {
      final rows = raw[table];
      if (rows == null) continue;
      if (rows is! List) throw FormatException('Tabela inválida no backup: $table');
      result[table] = rows.map((item) {
        if (item is! Map) throw FormatException('Registro inválido em $table.');
        return <String, Object?>{for (final entry in item.entries) '${entry.key}': entry.value};
      }).toList();
    }
    return result;
  }

  Map<String, dynamic> _decodeObject(List<int> bytes, String label) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) throw FormatException('$label inválido.');
      return <String, dynamic>{for (final entry in decoded.entries) '${entry.key}': entry.value};
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Não foi possível ler o $label do backup.');
    }
  }

  List<int> _entryBytes(Archive archive, String name) {
    for (final entry in archive) {
      if (entry.name == name && entry.isFile) {
        final bytes = entry.readBytes();
        if (bytes != null) return bytes;
      }
    }
    throw FormatException('Arquivo obrigatório ausente no backup: $name');
  }

  Map<String, String> _stringMap(Object? raw) {
    if (raw is! Map) return const {};
    return <String, String>{for (final entry in raw.entries) '${entry.key}': '${entry.value}'};
  }

  Future<String> _sha256File(File file) async => (await sha256.bind(file.openRead()).first).toString();

  Future<bool> _tableExists(DatabaseExecutor db, String table) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
      [table],
    );
    return rows.isNotEmpty;
  }

  Future<bool> _hasAnyAcademicData(Database db) async {
    for (final table in const ['subjects', 'tasks', 'notes', 'materials', 'class_sessions']) {
      final rows = await db.rawQuery('SELECT 1 FROM $table LIMIT 1');
      if (rows.isNotEmpty) return true;
    }
    return false;
  }

  Future<File> _uniqueDestination(Directory directory, String fileName) async {
    if (!await directory.exists()) await directory.create(recursive: true);
    var candidate = File(p.join(directory.path, fileName));
    if (!await candidate.exists()) return candidate;
    final base = p.basenameWithoutExtension(fileName);
    final extension = p.extension(fileName);
    for (var i = 2; i < 1000; i++) {
      candidate = File(p.join(directory.path, '$base ($i)$extension'));
      if (!await candidate.exists()) return candidate;
    }
    throw StateError('Não foi possível escolher um nome disponível para o backup.');
  }

  String _backupFileName(DateTime date, BackupKind kind) {
    String two(int value) => value.toString().padLeft(2, '0');
    final stamp = '${date.year}-${two(date.month)}-${two(date.day)}_${two(date.hour)}-${two(date.minute)}-${two(date.second)}';
    return 'AcademiaFlow_${kind.name}_$stamp.afbackup';
  }

  bool _safeStoredPath(String value) {
    if (value.isEmpty || value != p.basename(value)) return false;
    if (value.contains('..') || value.contains('/') || value.contains('\\')) return false;
    return true;
  }
}

class _BackupSnapshot {
  const _BackupSnapshot({required this.tables, required this.missingAttachments});

  final Map<String, List<Map<String, Object?>>> tables;
  final int missingAttachments;
}
