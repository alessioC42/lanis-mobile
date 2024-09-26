import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:countly_flutter_np/countly_flutter.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sph_plan/error_builders.dart';
import 'package:sph_plan/themes.dart';
import 'package:sph_plan/view/conversations/shared.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:sph_plan/startup.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter/material.dart';
import 'package:sph_plan/client/storage.dart';
import 'background_service.dart';
import 'package:http_proxy/http_proxy.dart';


void main() async {
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return errorWidget(details);
  };

  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await initializeNotifications();
    await setupBackgroundService();

    await initializeDateFormatting();
    if (!kDebugMode &&
        (await globalStorage.read(key: StorageKey.settingsUseCountly)) ==
            "true") {
      const String duckDNS =
          "duckdns.org"; //so web crawlers do not parse the URL from gh
      CountlyConfig config = CountlyConfig("https://lanis-mobile.$duckDNS",
          "4e7059ab732b4db3baaf75a6b3e1eef6d4aa3927");
      config.enableCrashReporting();

      config.setCustomCrashSegment({
        "school_id_storage":
            await globalStorage.read(key: StorageKey.userSchoolID),
        "account_is_student":
            jsonDecode(await globalStorage.read(key: StorageKey.userData))
                .containsKey("klasse"),
      });
      await Countly.initWithConfig(config);

      String schoolID = await globalStorage.read(key: StorageKey.userSchoolID);
      if (schoolID != "") {
        Countly.instance.views.startView(schoolID);
      }

      FlutterError.onError = (errorDetails) async {
        Countly.recordDartError(errorDetails.exception, errorDetails.stack!);
      };
    }

    ThemeModeNotifier.init();
    ColorModeNotifier.init();
    AmoledNotifier.init();

    HttpProxy httpProxy = await HttpProxy.createHttpProxy();

    addLogMessage('PROXY: ${httpProxy.host} ${httpProxy.port}');
    addLogMessage('PAC:\n\tIs used: ${await HttpProxy.isPACUsed()}\n\tURL: ${await HttpProxy.getPACURL()}');

    HttpOverrides.global=httpProxy;

    runApp(const App());
  }, (obj, stack) async {
    if (!kDebugMode &&
        await globalStorage.read(key: StorageKey.settingsUseCountly) ==
            "true") {
      await Countly.recordDartError(obj, stack);
    }
  });
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
      if (lightDynamic != null && darkDynamic != null) {
        Themes.dynamicTheme = Themes.getNewTheme(lightDynamic.primary);
        if (globalStorage.prefs.getString("color") == "dynamic") {
          ColorModeNotifier.set("dynamic", Themes.dynamicTheme);
        }
      }

      return ValueListenableBuilder<Themes>(
          valueListenable: ColorModeNotifier.notifier,
          builder: (_, theme, __) {
            return ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeModeNotifier.notifier,
                builder: (_, mode, __) {
                  return ValueListenableBuilder<bool>(
                    valueListenable: AmoledNotifier.notifier,
                    builder: (_, isAmoled, __) {
                      ThemeData darkTheme = getAmoledTheme(theme, isAmoled);

                      if (mode == ThemeMode.light || mode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.light) {
                        BubbleStyles.init(theme.lightTheme!);
                      } else if (mode == ThemeMode.dark || mode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark) {
                        BubbleStyles.init(darkTheme);
                      }
                      return MaterialApp(
                        title: 'Lanis Mobile',
                        theme: theme.lightTheme,
                        darkTheme: darkTheme,
                        themeMode: mode,
                        localizationsDelegates: AppLocalizations.localizationsDelegates,
                        supportedLocales: AppLocalizations.supportedLocales,
                        home: const InbetweenClass(),
                      );
                    }
                  );
                });
          });
    });
  }
}


class InbetweenClass extends StatefulWidget {
  const InbetweenClass({super.key});

  @override
  State<StatefulWidget> createState() => _InbetweenClassState();
}

class _InbetweenClassState extends State<StatefulWidget> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const StartupScreen(),)
          );
        }, child: Text("start")),
      ),
      floatingActionButton: getAPPFAB(context),
    );
  }
}


Widget errorWidget(FlutterErrorDetails details, {BuildContext? context}) {
  return ListView(children: [
    Container(
      color: Colors.red.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.only(
            left: 20.0, right: 20.0, top: 32.0, bottom: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.warning,
              size: 60,
            ),
            const Padding(
              padding: EdgeInsets.all(35),
              child: Text("Whoops! An error occurred.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  )),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 35, left: 20, right: 20),
              child: Text(
                "Problem: ${details.exception.toString()}",
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 35),
              child: FilledButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(
                        text: Trace.from(details.stack!).terse.toString()));
                  },
                  style: ButtonStyle(
                    overlayColor: WidgetStateProperty.resolveWith((states) {
                      return Colors.redAccent;
                    }),
                    foregroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      return Colors.white;
                    }),
                    backgroundColor:
                        WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.pressed)) {
                        return Colors.redAccent;
                      }
                      return Colors.red;
                    }),
                  ),
                  child: const Text(
                    "Copy error details to clipboard",
                  )),
            ),
          ],
        ),
      ),
    )
  ]);
}
