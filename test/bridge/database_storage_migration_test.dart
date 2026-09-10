import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/bridge/database_storage_migration.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  late Directory cache;
  late Directory persistent;

  setUp(() {
    root = Directory.systemTemp.createTempSync('database_migration_');
    cache = Directory(p.join(root.path, 'cache'))..createSync();
    persistent = Directory(p.join(root.path, 'support'))..createSync();
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> writeDatabaseFiles(Directory directory, String value) async {
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      await File(
        p.join(directory.path, '$lanisDatabaseFileName$suffix'),
      ).writeAsString(value);
    }
  }

  test(
    'moves the database and SQLite sidecars to persistent storage',
    () async {
      await writeDatabaseFiles(cache, 'legacy');

      final path = await migrateLanisDatabaseFromCache(
        cacheDirectory: cache,
        persistentDirectory: persistent,
      );

      expect(path, p.join(persistent.path, lanisDatabaseFileName));
      for (final suffix in ['', '-wal', '-shm', '-journal']) {
        expect(
          File(
            p.join(persistent.path, '$lanisDatabaseFileName$suffix'),
          ).readAsStringSync(),
          'legacy',
        );
        expect(
          File(
            p.join(cache.path, '$lanisDatabaseFileName$suffix'),
          ).existsSync(),
          isFalse,
        );
      }
    },
  );

  test(
    'keeps the persistent database when migration has already completed',
    () async {
      await writeDatabaseFiles(cache, 'legacy');
      await writeDatabaseFiles(persistent, 'persistent');

      final path = await migrateLanisDatabaseFromCache(
        cacheDirectory: cache,
        persistentDirectory: persistent,
      );

      expect(path, p.join(persistent.path, lanisDatabaseFileName));
      expect(
        File(p.join(persistent.path, lanisDatabaseFileName)).readAsStringSync(),
        'persistent',
      );
      expect(
        File(p.join(cache.path, lanisDatabaseFileName)).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'returns the persistent path when there is no legacy database',
    () async {
      final path = await migrateLanisDatabaseFromCache(
        cacheDirectory: cache,
        persistentDirectory: persistent,
      );

      expect(path, p.join(persistent.path, lanisDatabaseFileName));
    },
  );
}
