import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:liblanis/liblanis.dart';

final openLanisDefinition = ExternalDefinition(
  id: 'openLanis',
  label: (context) => AppLocalizations.of(context).openLanisInBrowser,
  // Flip to true to pin this shortcut on the tablet navigation rail.
  showInNavigationRail: false,
  action: (context) {
    if (context == null) return;
    final container = ProviderScope.containerOf(context);
    final account = container.read(activeAccountProvider);
    if (account == null) return;
    final config = container.read(lanisConfigProvider);
    LanisSession.getLoginURL(account, config)
        .then((response) {
          if (!context.mounted) return;
          safeLaunchUrl(Uri.parse(response), context: context);
        })
        .catchError((Object error, StackTrace stackTrace) {
          debugPrint('Failed to open Lanis login URL: $error');
        });
  },
);

final openMoodleDefinition = ExternalDefinition(
  id: 'openMoodle',
  label: (context) => AppLocalizations.of(context).openMoodle,
  // Flip to true to pin this shortcut on the tablet navigation rail.
  showInNavigationRail: false,
  action: (context) {
    if (context == null) {
      return;
    }
    context.push(SettingsDeepLinks.moodle);
  },
);
