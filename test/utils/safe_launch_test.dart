import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  final originalLauncher = launchUrlImpl;
  final uri = Uri.parse('https://example.com');

  tearDown(() {
    launchUrlImpl = originalLauncher;
  });

  test('returns false when the launcher throws and does not rethrow', () async {
    launchUrlImpl =
        (url, {LaunchMode mode = LaunchMode.platformDefault}) async {
          throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
        };

    expect(await safeLaunchUrl(uri), isFalse);
  });

  test('returns false when the launcher reports failure', () async {
    launchUrlImpl =
        (url, {LaunchMode mode = LaunchMode.platformDefault}) async {
          return false;
        };

    expect(await safeLaunchUrl(uri), isFalse);
  });

  test('returns true when the launcher succeeds', () async {
    launchUrlImpl =
        (url, {LaunchMode mode = LaunchMode.platformDefault}) async {
          return true;
        };

    expect(await safeLaunchUrl(uri), isTrue);
  });
}
