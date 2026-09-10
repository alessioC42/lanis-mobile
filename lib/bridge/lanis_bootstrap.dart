import 'dart:async';

import 'package:liblanis/liblanis.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod/misc.dart' show Override;

import '../core/native_adapter_instance.dart';
import '../utils/glitchtip.dart';
import 'database_storage_migration.dart';
import 'flutter_secret_store.dart';

/// Configures [LanisClient] for the Flutter host and returns Riverpod overrides.
Future<List<Override>> bootstrapLanisClient({
  FlutterSecretStore? secretStore,
}) async {
  final cacheDir = await getApplicationCacheDirectory();
  final persistentDir = await getApplicationSupportDirectory();
  final tempDir = await getTemporaryDirectory();
  final packageInfo = await PackageInfo.fromPlatform();
  final store = secretStore ?? FlutterSecretStore();
  final databasePath = await migrateLanisDatabaseFromCache(
    cacheDirectory: cacheDir,
    persistentDirectory: persistentDir,
  );

  return LanisClient.configure(
    databasePath: databasePath,
    secretStore: store,
    documentCacheDirectory: p.join(tempDir.path, 'lanis_documents'),
    httpAdapter: getNativeAdapterInstance(),
    userAgent:
        'Lanis-Mobile/v${packageInfo.version}+${packageInfo.buildNumber}',
    onUnexpectedError: (error, stackTrace, {required appletPhpUrl}) {
      unawaited(
        captureUnexpectedAppletError(
          error,
          stackTrace,
          appletPhpUrl: appletPhpUrl,
        ),
      );
    },
  );
}
