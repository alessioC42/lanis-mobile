import 'dart:io';

import 'package:path/path.dart' as p;

import '../utils/logger.dart';

const lanisDatabaseFileName = 'lanis.db';

const _sqliteSidecarSuffixes = <String>['-wal', '-shm', '-journal'];

Future<String> migrateLanisDatabaseFromCache({
  required Directory cacheDirectory,
  required Directory persistentDirectory,
}) async {
  final sourceFiles = _databaseFiles(cacheDirectory);
  final targetFiles = _databaseFiles(persistentDirectory);
  final sourceDatabase = sourceFiles.first;
  final targetDatabase = targetFiles.first;

  if (!sourceDatabase.existsSync()) return targetDatabase.path;

  try {
    await persistentDirectory.create(recursive: true);

    if (targetDatabase.existsSync()) {
      await _deleteFiles(sourceFiles);
      return targetDatabase.path;
    }

    await _restoreFiles(sourceFiles, targetFiles);

    final moved = <({File source, File target})>[];
    try {
      for (var i = 1; i < sourceFiles.length; i++) {
        if (!sourceFiles[i].existsSync()) continue;
        await sourceFiles[i].rename(targetFiles[i].path);
        moved.add((source: sourceFiles[i], target: targetFiles[i]));
      }

      await sourceDatabase.rename(targetDatabase.path);
      moved.add((source: sourceDatabase, target: targetDatabase));
    } catch (_) {
      for (final entry in moved.reversed) {
        try {
          await entry.target.rename(entry.source.path);
        } catch (rollbackError, rollbackStackTrace) {
          logger.e(
            'Failed to roll back database migration: $rollbackError',
            stackTrace: rollbackStackTrace,
          );
        }
      }
      rethrow;
    }

    logger.i(
      'Moved database successfully from ${sourceDatabase.path} to ${targetDatabase.path}',
    );
    return targetDatabase.path;
  } catch (error, stackTrace) {
    logger.e('Could not move Lanis database: $error', stackTrace: stackTrace);
    return targetDatabase.existsSync()
        ? targetDatabase.path
        : sourceDatabase.path;
  }
}

List<File> _databaseFiles(Directory directory) => [
  for (final suffix in ['', ..._sqliteSidecarSuffixes])
    File(p.join(directory.path, '$lanisDatabaseFileName$suffix')),
];

Future<void> _restoreFiles(
  List<File> sourceFiles,
  List<File> targetFiles,
) async {
  for (var i = 1; i < sourceFiles.length; i++) {
    final source = sourceFiles[i];
    final target = targetFiles[i];
    if (!target.existsSync()) continue;

    if (!source.existsSync()) {
      await target.rename(source.path);
    } else {
      await target.delete();
    }
  }
}

Future<void> _deleteFiles(Iterable<File> files) async {
  for (final file in files) {
    if (!file.existsSync()) continue;
    try {
      await file.delete();
    } catch (error, stackTrace) {
      logger.e(
        'Failed to remove old database file ${file.path}: $error',
        stackTrace: stackTrace,
      );
    }
  }
}
