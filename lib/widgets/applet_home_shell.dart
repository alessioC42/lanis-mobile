import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/applets/definitions.dart';
import 'package:lanis/utils/responsive.dart';

/// Chrome owned by [HomePage]: drawer + branch switching for nested applets.
///
/// The phone [NavigationBar] is *not* on [HomePage]; it lives in
/// [appletHomeShell] so detail pushes cover it naturally.
class HomeChrome extends InheritedWidget {
  final StatefulNavigationShell navigationShell;
  final void Function(int index) goBranch;
  final VoidCallback openDrawer;

  const HomeChrome({
    super.key,
    required this.navigationShell,
    required this.goBranch,
    required this.openDrawer,
    required super.child,
  });

  static HomeChrome? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeChrome>();
  }

  static HomeChrome of(BuildContext context) {
    final chrome = maybeOf(context);
    assert(chrome != null, 'HomeChrome not found in context');
    return chrome!;
  }

  @override
  bool updateShouldNotify(HomeChrome oldWidget) {
    return navigationShell != oldWidget.navigationShell ||
        goBranch != oldWidget.goBranch ||
        openDrawer != oldWidget.openDrawer;
  }
}

/// Wraps an applet list root (`…/home`) so the phone bottom bar sits under the
/// home page and is covered when sibling detail routes are pushed.
///
/// Tablet: returns [child] only (rail lives on the outer [HomePage]).
RouteBase appletHomeShell({
  required GoRouterWidgetBuilder homeBuilder,
  String homePath = 'home',
}) {
  return ShellRoute(
    builder: (context, state, child) {
      if (Responsive.isTablet(context)) return child;
      return _PhoneAppletBottomNav(child: child);
    },
    routes: [GoRoute(path: homePath, builder: homeBuilder)],
  );
}

class _PhoneAppletBottomNav extends ConsumerWidget {
  final Widget child;

  const _PhoneAppletBottomNav({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chrome = HomeChrome.of(context);
    final supported = ref.watch(supportedAppletPhpUrlsProvider);
    final accountType = ref.watch(
      activeAccountProvider.select((account) => account?.accountType),
    );
    final nested = AppDefinitions.homeApplets;
    final indexes = <int>[];
    final defs = <AppletDefinition>[];
    for (var i = 0; i < nested.length; i++) {
      if (accountType != null &&
          nested[i].supportedAccountTypes.contains(accountType) &&
          supported.contains(nested[i].appletPhpUrl)) {
        indexes.add(i);
        defs.add(nested[i]);
      }
    }
    if (defs.isEmpty) return child;

    final current = chrome.navigationShell.currentIndex;
    final selectedInBar = indexes.indexOf(current);

    // Mimic Scaffold.bottomNavigationBar MediaQuery contract:
    // - Body/FAB: bottom padding removed so FABs are not lifted by a second
    //   system-nav inset (the bar below already consumes that space).
    // - NavigationBar: top padding removed so its SafeArea does not insert a
    //   status-bar gap; bottom padding kept for the system nav.
    return Column(
      children: [
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: child,
          ),
        ),
        MediaQuery.removePadding(
          context: context,
          removeTop: true,
          child: NavigationBar(
            destinations: [
              for (final def in defs)
                NavigationDestination(
                  label: def.label(context),
                  icon: def.icon,
                  selectedIcon: def.selectedIcon,
                ),
            ],
            selectedIndex: selectedInBar < 0 ? 0 : selectedInBar,
            onDestinationSelected: (int index) =>
                chrome.goBranch(indexes[index]),
            labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          ),
        ),
      ],
    );
  }
}
