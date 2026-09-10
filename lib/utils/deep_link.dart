import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/l10n/account_type_ui.dart';
import 'package:lanis/widgets/error_view.dart';

/// Path prefixes for `lanis://` deep links / go_router locations.
///
/// - [common]: applets whose UI does not differ by [AccountType]
/// - otherwise use [AccountType.name] (`student`, `teacher`, `parent`)
abstract final class DeepLinkPrefixes {
  static const common = 'common';

  static String forAccount(AccountType type) => type.name;

  static String forScope(DeepLinkScope scope, AccountType accountType) =>
      scope == DeepLinkScope.common ? common : accountType.name;
}

enum DeepLinkScope { common, accountTyped }

/// Thrown for unsupported / mismatched / unknown deep links.
class DeepLinkException implements Exception {
  final String message;
  DeepLinkException(this.message);

  @override
  String toString() => message;
}

/// Normalizes a `lanis://` URI (or any URI) to a go_router location path.
///
/// Examples:
/// - `lanis://common/substitutions/home` → `/common/substitutions/home`
/// - `lanis:///student/lessons/home` → `/student/lessons/home`
String? deepLinkLocationFromUri(Uri uri) {
  if (uri.scheme.isNotEmpty && uri.scheme != 'lanis') {
    return null;
  }
  final host = uri.host;
  final path = uri.path;
  if (host.isNotEmpty) {
    final joined = path.isEmpty || path == '/'
        ? '/$host'
        : '/$host${path.startsWith('/') ? path : '/$path'}';
    return _withQuery(joined, uri);
  }
  if (path.isEmpty || path == '/') return null;
  final normalized = path.startsWith('/') ? path : '/$path';
  return _withQuery(normalized, uri);
}

String _withQuery(String path, Uri uri) {
  if (uri.hasQuery) return '$path?${uri.query}';
  return path;
}

/// First path segment if it is a known account / common prefix.
String? deepLinkPrefixOf(String location) {
  final parts = Uri.parse(location).pathSegments;
  if (parts.isEmpty) return null;
  final p = parts.first;
  if (p == DeepLinkPrefixes.common) return p;
  for (final t in AccountType.values) {
    if (t.name == p) return p;
  }
  return null;
}

/// Whether [location]'s prefix matches the session [accountType] rules.
///
/// `common` is always allowed (applet support checked separately).
/// Account-typed prefixes must equal [accountType].name.
bool deepLinkPrefixAllowed(String location, AccountType accountType) {
  final prefix = deepLinkPrefixOf(location);
  if (prefix == null) return false;
  if (prefix == DeepLinkPrefixes.common) return true;
  return prefix == accountType.name;
}

/// Full-screen error for bad deep links.
class DeepLinkErrorPage extends StatelessWidget {
  final Exception error;
  final String? fallbackPath;

  const DeepLinkErrorPage({super.key, required this.error, this.fallbackPath});

  void _goBack(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else if (fallbackPath != null) {
      context.go(fallbackPath!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      appBar: AppBar(
        leading: fallbackPath == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => _goBack(context),
              ),
      ),
      body: AppletErrorView(error: error),
    );
    if (fallbackPath == null) return page;
    return DeepLinkPopScope(fallbackPath: fallbackPath!, child: page);
  }
}

/// On system back: pop if possible, otherwise [go] to [fallbackPath].
///
/// Ensures cold-opened detail routes (e.g. filter) do not exit the app.
class DeepLinkPopScope extends StatelessWidget {
  final String fallbackPath;
  final Widget child;

  const DeepLinkPopScope({
    super.key,
    required this.fallbackPath,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Use the local [Navigator] — go_router's [canPop] can be true for
        // shell chrome even when this detail was opened with [GoRouter.go]
        // and has no page underneath.
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop(result);
        } else {
          context.go(fallbackPath);
        }
      },
      child: child,
    );
  }
}

/// Settings paths under `/common/settings/…`.
abstract final class SettingsDeepLinks {
  static const base = '/common/settings';
  static const home = '$base/home';
  static const appearance = '$base/appearance';
  static const notifications = '$base/notifications';
  static const cache = '$base/cache';
  static const userdata = '$base/userdata';
  static const about = '$base/about';
  static const errorReporting = '$base/error-reporting';
  static const calendarExport = '$base/calendar-export';
  static const timetable = '$base/timetable';
  static const moodle = '/common/moodle';
  static const deepLinkError = '/deep-link-error';
}
