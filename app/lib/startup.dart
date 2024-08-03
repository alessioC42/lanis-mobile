import 'dart:convert';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:simple_shadow/simple_shadow.dart';
import 'package:sph_plan/client/client_submodules/substitutions.dart';
import 'package:sph_plan/client/storage.dart';
import 'package:sph_plan/home_page.dart';
import 'package:sph_plan/shared/exceptions/client_status_exceptions.dart';
import 'package:sph_plan/shared/types/fach.dart';
import 'package:sph_plan/shared/widgets/whats_new.dart';
import 'package:sph_plan/view/login/auth.dart';
import 'package:sph_plan/view/login/screen.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sph_plan/view/substitutions/view.dart';
import 'package:sph_plan/view/timetable/view.dart';
import 'package:url_launcher/url_launcher.dart';

import 'client/client.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  LanisException? error;

  // We need to load storage first, so we have to wait before everything.
  ValueNotifier<bool> finishedLoadingStorage = ValueNotifier<bool>(false);


  void openWelcomeScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WelcomeLoginScreen()),
    ).then((_) async {
      await client.prepareDio();

      // Context should be mounted
      // ignore: use_build_context_synchronously
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    });
  }

  void openLoginScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => Scaffold(
                  body: LoginForm(
                afterLogin: () async {
                  await client.loadFromStorage();
                  await client.prepareDio();

                  // ignore: use_build_context_synchronously
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomePage()),
                  );
                },
                relogin: true,
              ))),
    );
  }

  Future<void> performLogin() async {
    await client.prepareDio();
    if (client.username == "") {
      openWelcomeScreen();
      return;
    }

    try {
      await client.login();

      if (error == null) {
        whatsNew().then((value) {
          if (value != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => ReleaseNotesScreen(value)),
            ).then((_) => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomePage()),
                ));
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          }
        });
      }
      return;
    } on WrongCredentialsException {
      openWelcomeScreen();
    } on CredentialsIncompleteException {
      openWelcomeScreen();
    } on LanisException catch (e) {
      error = e;
      showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return errorDialog();
          }
      );
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      client.loadFromStorage().then((_) {
        finishedLoadingStorage.value = true;
        performLogin();
      });
    });

    super.initState();
  }

  @override
  void dispose() {
    finishedLoadingStorage.dispose();
    super.dispose();
  }
  
  /// Either school image or app version.
  Widget schoolLogo() {
    var darkMode = Theme.of(context).brightness == Brightness.dark;

    Widget deviceInfo = FutureBuilder(
      future: PackageInfo.fromPlatform(),
      builder: (context, packageInfo) {
        return Text(
          "lanis-mobile ${packageInfo.data?.version}",
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25)),
        );
      },
    );

    return CachedNetworkImage(
      imageUrl:
          "https://startcache.schulportal.hessen.de/exporteur.php?a=schoollogo&i=${client.schoolID}",
      fadeInDuration: const Duration(milliseconds: 0),
      placeholder: (context, url) => deviceInfo,
      errorWidget: (context, url, error) => deviceInfo,
      imageBuilder: (context, imageProvider) => ColorFiltered(
        colorFilter: darkMode
            ? const ColorFilter.matrix([
                -1, 0, 0, 0,
                255, 0, -1, 0,
                0, 255, 0, 0,
                -1, 0, 255, 0,
                0, 0, 1, 0
              ])
            : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
        child: Image(
          image: imageProvider,
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget appLogo(double horizontal, double vertical) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      child: LayoutBuilder(builder: (context, constraints) {
        return SimpleShadow(
          color: Theme.of(context).colorScheme.surfaceTint,
          opacity: 0.25,
          sigma: 6,
          offset: const Offset(4, 8),
          child: SvgPicture.asset(
            "assets/startup.svg",
            colorFilter: ColorFilter.mode(Theme.of(context).colorScheme.primary, BlendMode.srcIn),
            fit: BoxFit.contain,
            width: constraints.maxWidth.clamp(0, 300),
            height: constraints.maxHeight.clamp(0, 250),
          ),
        );
      }),
    );
  }

  WidgetSpan toolTipIcon(IconData icon) {
    return WidgetSpan(child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.onPrimary,));
  }

  Widget tipText(EdgeInsets padding, EdgeInsets margin, double? width) {
    List<Widget> toolTips = <Widget>[
      Text.rich(TextSpan(
        text: AppLocalizations.of(context)!.startUpMessage1,
        children: [
          toolTipIcon(Icons.code)
        ]
      )),
      Text.rich(TextSpan(
        text: AppLocalizations.of(context)!.startUpMessage2,
        children: [
          toolTipIcon(Icons.people)
        ]
      )),
      Text.rich(TextSpan(
        text: AppLocalizations.of(context)!.startUpMessage3,
        children: [
          toolTipIcon(Icons.filter_alt)
        ]
      )),
      Text.rich(TextSpan(
          text: AppLocalizations.of(context)!.startUpMessage4,
          children: [
            toolTipIcon(Icons.star)
          ]
      )),
      Text(AppLocalizations.of(context)!.startUpMessage5),
      Text(AppLocalizations.of(context)!.startUpMessage6),
      Text.rich(TextSpan(
          text: AppLocalizations.of(context)!.startUpMessage7,
          children: [
            toolTipIcon(Icons.favorite)
          ]
      )),
      Text.rich(TextSpan(
          text: AppLocalizations.of(context)!.startUpMessage8,
          children: [
            toolTipIcon(Icons.code)
          ]
      )),
      Text.rich(TextSpan(
          text: AppLocalizations.of(context)!.startUpMessage9,
          children: [
            toolTipIcon(Icons.settings)
          ]
      )),
    ];

    return Container(
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withAlpha(85),
                blurRadius: 18,
                spreadRadius: 1,
              )
            ],
            borderRadius: BorderRadius.circular(16.0)),
        padding: padding,
        margin: margin,
        width: width,
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.labelLarge!.copyWith(color: Theme.of(context).colorScheme.onPrimary),
          textAlign: TextAlign.center,
          child: toolTips.elementAt(Random().nextInt(toolTips.length)),
        )
    );
  }


  Widget errorDialog() {
    return AlertDialog(
      icon: error is NoConnectionException
          ? const Icon(Icons.wifi_off)
          : const Icon(Icons.error),
      title: Text(error is NoConnectionException
          ? AppLocalizations.of(context)!.noInternetConnection2
          : AppLocalizations.of(context)!.startupError),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (error is! NoConnectionException) Text.rich(TextSpan(
              text: AppLocalizations.of(context)!.startupErrorMessage,
              children: [
                TextSpan(
                    text: "\n\n${error.runtimeType}: ${error!.cause}",
                    style: Theme.of(context).textTheme.labelLarge)
              ])),
          const OfflineAppletSelector()
        ],
      ),
      actions: [
        if (error is! NoConnectionException) ...[
          TextButton(
              onPressed: () {
                launchUrl(Uri.parse("https://github.com/alessioC42/lanis-mobile/issues"));
              },
              child: const Text("GitHub")
          ),
          OutlinedButton(
              onPressed: () {
                launchUrl(Uri.parse("mailto:alessioc42.dev@gmail.com"));
              },
              child: Text(AppLocalizations.of(context)!.startupReportButton)
          ),
        ],
        FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();

              error = null;
              await performLogin();
            },
            child: Text(AppLocalizations.of(context)!.startupRetryButton)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SafeArea(
            child: MediaQuery.of(context).orientation == Orientation.portrait
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      schoolLogo(),
                      Column(
                        children: [
                          appLogo(80.0, 20.0),
                          tipText(
                              const EdgeInsets.symmetric(
                                  vertical: 10.0, horizontal: 12.0),
                              const EdgeInsets.symmetric(horizontal: 36.0), null)
                        ],
                      ),
                      const LinearProgressIndicator()
                    ],
                  )
                : Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      schoolLogo(),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              appLogo(0.0, 0.0),
                              SizedBox.fromSize(
                                size: const Size(48.0, 0.0),
                              ),
                              tipText(
                                  const EdgeInsets.symmetric(
                                      vertical: 16.0, horizontal: 12.0),
                                  const EdgeInsets.only(), 250)
                            ],
                          ),
                        ],
                      ),
                      const Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [LinearProgressIndicator()],
                      )
                    ],
                  )));
  }
}

class OfflineAppletSelector extends StatefulWidget {
  const OfflineAppletSelector({super.key});

  @override
  State<OfflineAppletSelector> createState() => _OfflineAppletSelectorState();
}

//handling just 2 applets (substitution and timetable) does not require a scalable solution. When adding offline support for more applets we should adapt to creating the config from a single location maybe even integrating the list from [home_page.dart]
class _OfflineAppletSelectorState extends State<OfflineAppletSelector> {
  SubstitutionPlan? substitutionData;
  List<List<StdPlanFach>>? timetableData;
  bool loading = true;

  List<Widget> appletList = [];

  Widget appletListTile(String title, IconData icon, Function action) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: () {
            action();
          },
        ),
        Text(title)
      ],
    );
  }
  Future<void> loadAppletData() async {
    String substitutionJson = await globalStorage.read(key: StorageKey.lastSubstitutionData);
    String timetableJson = await globalStorage.read(key: StorageKey.lastTimetableData);
    if (substitutionJson != "") {
      substitutionData = SubstitutionPlan.fromJson(jsonDecode(substitutionJson));
      appletList.add(appletListTile(AppLocalizations.of(context)!.substitutions, Icons.calendar_today, () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text("${AppLocalizations.of(context)!.substitutions} (${AppLocalizations.of(context)!.offline})"),
            ),
            body: StaticSubstitutionsView(
                plan: substitutionData,
                refresh: null,
                )
            )
          )
        );
      }));
    }
    if (timetableJson != "") {
      timetableData = List<List<StdPlanFach>>.from(jsonDecode(timetableJson).map((e) => List<StdPlanFach>.from(e.map((e) => StdPlanFach.fromJson(e)))));

      appletList.add(appletListTile(AppLocalizations.of(context)!.timeTable, Icons.calendar_today, () {
        Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Scaffold(
                appBar: AppBar(
                  title: Text("${AppLocalizations.of(context)!.timeTable} (${AppLocalizations.of(context)!.offline})"),
                ),
                body: StaticTimetableView(
                  data: timetableData,
                  refresh: null,
                )
            )
            )
        );
      })
      );
    }
    setState(() {
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    loadAppletData();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: appletList,
    );
  }
}
