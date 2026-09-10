import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/startup.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/utils/auth_redirect.dart';
import 'package:lanis/utils/deep_link.dart';
import 'package:lanis/utils/responsive.dart';
import 'package:lanis/view/account_switcher/account_switcher.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/utils/glitchtip_navigation.dart';
import 'package:lanis/view/login/auth.dart';
import 'package:lanis/view/login/screen.dart';
import 'package:lanis/view/moodle.dart';
import 'package:lanis/view/privacy_policy/privacy_policy_screen.dart';
import 'package:lanis/view/settings/settings_routes.dart';
import 'package:lanis/widgets/applet_home_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

Widget _homeAppletBody(AppletDefinition def) {
  return Consumer(
    builder: (context, ref, _) {
      final accountType =
          ref.watch(activeAccountProvider.select((a) => a?.accountType)) ??
          AccountType.student;
      final chrome = HomeChrome.maybeOf(context);
      final openDrawer = Responsive.isTablet(context)
          ? null
          : () => chrome?.openDrawer();
      final builder = def.bodyBuilder;
      if (builder == null) {
        return const SizedBox.shrink();
      }
      return builder(context, accountType, openDrawer);
    },
  );
}

AppletRouteContext _routeContext() => AppletRouteContext(
  rootNavigatorKey: rootNavigatorKey,
  homeBody: _homeAppletBody,
);

bool _isSettingsPath(String loc) =>
    loc == SettingsDeepLinks.base ||
    loc.startsWith('${SettingsDeepLinks.base}/');

bool _isMoodlePath(String loc) => loc == SettingsDeepLinks.moodle;

bool _isSupportedShellPath(Ref ref, String loc) {
  final def = AppDefinitions.findMatchingLocation(loc);
  if (def != null) {
    return ref.read(supportedAppletPhpUrlsProvider).contains(def.appletPhpUrl);
  }
  if (_isSettingsPath(loc) || _isMoodlePath(loc)) return true;
  return true;
}

String? _deepLinkAuthRedirect(Ref ref, String loc) {
  final account =
      ref.read(activeAccountProvider)?.accountType ?? AccountType.student;

  if (loc == SettingsDeepLinks.deepLinkError) return null;

  // Moodle / settings: require common prefix.
  if (_isMoodlePath(loc) || _isSettingsPath(loc)) {
    if (!deepLinkPrefixAllowed(loc, account)) {
      return SettingsDeepLinks.deepLinkError;
    }
    return null;
  }

  final def = AppDefinitions.findMatchingLocation(loc);
  if (def == null) {
    // Unknown deep path under a known prefix → error
    if (deepLinkPrefixOf(loc) != null &&
        loc != '/startup' &&
        loc != '/welcome' &&
        loc != '/login' &&
        loc != '/accounts') {
      return SettingsDeepLinks.deepLinkError;
    }
    return null;
  }

  if (!deepLinkPrefixAllowed(loc, account)) {
    return SettingsDeepLinks.deepLinkError;
  }

  if (!ref.read(supportedAppletPhpUrlsProvider).contains(def.appletPhpUrl)) {
    return SettingsDeepLinks.deepLinkError;
  }

  if (!def.supportedAccountTypes.contains(account)) {
    return SettingsDeepLinks.deepLinkError;
  }

  // Teacher lessons: only /home allowed.
  if (def.pathSegment == 'lessons' &&
      account == AccountType.teacher &&
      !loc.endsWith('/home') &&
      loc != def.basePath(account)) {
    return SettingsDeepLinks.deepLinkError;
  }

  return null;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);

  final routeCtx = _routeContext();

  final shellBranches = <StatefulShellBranch>[
    for (final def in AppDefinitions.homeApplets)
      StatefulShellBranch(
        // Separate observer instance per navigator (Sentry forbids sharing one).
        observers: [glitchTipNavigatorObserver()],
        initialLocation: def.homePath(
          def.deepLinkScope == DeepLinkScope.common
              ? null
              : (ref.read(activeAccountProvider)?.accountType ??
                    def.supportedAccountTypes.first),
        ),
        routes: def.buildRoutes(routeCtx),
      ),
    for (final def in AppDefinitions.navigationApplets)
      StatefulShellBranch(
        observers: [glitchTipNavigatorObserver()],
        initialLocation: def.homePath(
          def.deepLinkScope == DeepLinkScope.common
              ? null
              : (ref.read(activeAccountProvider)?.accountType ??
                    def.supportedAccountTypes.first),
        ),
        routes: def.buildRoutes(routeCtx),
      ),
    StatefulShellBranch(
      observers: [glitchTipNavigatorObserver()],
      initialLocation: SettingsDeepLinks.home,
      routes: buildSettingsRoutes(),
    ),
  ];

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/startup',
    refreshListenable: listenable,
    // Breadcrumbs for error context only (traces are disabled in GlitchTip config).
    observers: [glitchTipNavigatorObserver()],
    redirect: (context, state) {
      // Normalize lanis://host/path → /host/path for go_router matching.
      if (state.uri.scheme == 'lanis') {
        final normalized = deepLinkLocationFromUri(state.uri);
        if (normalized != null) return normalized;
      }

      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;
      final onShell =
          AppDefinitions.findMatchingLocation(loc) != null ||
          _isSettingsPath(loc);

      final shared = ref.read(sharedOverAccountSettingsProvider);
      final accounts = ref.read(accountsProvider).asData?.value;
      final deepErr = auth.phase == AuthPhase.authenticated
          ? _deepLinkAuthRedirect(ref, loc)
          : null;

      return resolveAuthRedirect(
        phase: auth.phase,
        loc: loc,
        privacyAccepted: isPrivacyPolicyAccepted(shared),
        hasAccounts: accounts?.isNotEmpty ?? false,
        isShellPath: onShell,
        shellSupported: onShell ? _isSupportedShellPath(ref, loc) : true,
        deepLinkErrorPath: deepErr,
        homePath: () => firstSupportedHomePathFromRef(ref),
      );
    },
    routes: [
      GoRoute(
        path: '/startup',
        builder: (context, state) => const StartupScreen(),
      ),
      GoRoute(
        path: '/privacy-policy',
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeLoginScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) =>
            const Scaffold(body: LoginForm(showBackButton: true)),
      ),
      GoRoute(
        path: SettingsDeepLinks.deepLinkError,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => DeepLinkErrorPage(
          error: DeepLinkException(
            state.uri.queryParameters['message'] ??
                'This link is not available for your account.',
          ),
          fallbackPath: firstSupportedHomePathFromRef(ref),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return HomePage(navigationShell: navigationShell);
        },
        branches: shellBranches,
      ),
      GoRoute(
        path: SettingsDeepLinks.moodle,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const MoodleWebView(),
      ),
      // Legacy alias
      GoRoute(
        path: '/moodle',
        redirect: (context, state) => SettingsDeepLinks.moodle,
      ),
      GoRoute(
        path: '/accounts',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AccountSwitcher(),
      ),
    ],
  );

  final detachRouteTracking = attachGlitchTipRouteTracking(router);
  ref.onDispose(detachRouteTracking);
  return router;
});

/// Notifies [GoRouter] when auth phase or account list changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this.ref) {
    ref.listen(authControllerProvider, (_, _) => notifyListeners());
    ref.listen(accountsProvider, (_, _) => notifyListeners());
  }

  final Ref ref;
}
