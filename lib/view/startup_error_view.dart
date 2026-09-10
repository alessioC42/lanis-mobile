import 'dart:io' show exit, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lanis/bridge/flutter_secret_store.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// This view is only rendered, if an error in the main function is thrown as a last resort to show the error to the user.
///
/// It is designed to use as little dependencies as possible to avoid further errors. It only uses Flutter's built-in widgets and does not rely on any external packages or custom widgets.
class StartupErrorView extends StatefulWidget {
  final FlutterErrorDetails errorDetails;
  const StartupErrorView({super.key, required this.errorDetails});

  @override
  State<StartupErrorView> createState() => _StartupErrorViewState();
}

class _StartupErrorViewState extends State<StartupErrorView> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Kritischer Fehler"),
          backgroundColor: Colors.red,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              "Beim Starten der App ist ein Fehler aufgetreten. Bitte sende den folgenden Fehlerbericht an die Entwickler, damit sie das Problem beheben können.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final errorReport = await generateErrorReport(
                  widget.errorDetails,
                );
                Clipboard.setData(ClipboardData(text: errorReport));
              },
              child: Text("Fehlerbericht kopieren"),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => sendEmail(widget.errorDetails),
              child: Text("E-Mail"),
            ),
            ElevatedButton(
              onPressed: () async {
                final confirmation = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text("App zurücksetzen?"),
                    content: Text(
                      "Möchtest du wirklich alle Daten der App löschen und die App zurücksetzen? Diese Aktion kann nicht rückgängig gemacht werden.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text("Abbrechen"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text("Zurücksetzen"),
                      ),
                    ],
                  ),
                );
                if (confirmation == true) forceReset();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text("App zurücksetzen"),
            ),
            SizedBox(height: 8),
            Text(
              widget.errorDetails.exceptionAsString(),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.errorDetails.stack.toString(),
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
            Text(
              logger.getHistory(),
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<String> generateErrorReport(FlutterErrorDetails errorDetails) async {
  final now = DateTime.now().toIso8601String().replaceAll(":", "-");

  String errorReport =
      "${errorDetails.exception.toString()}\n${errorDetails.stack}\n\n${logger.getHistory()}";
  errorReport += "\n\n[DEVICE INFO]\n";
  errorReport +=
      "OS: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}\n";
  final PackageInfo packageInfo = await PackageInfo.fromPlatform();

  errorReport += "App Version: ${packageInfo.version}\n";
  errorReport += "Build Number: ${packageInfo.buildNumber}\n";
  errorReport += "Package Name: ${packageInfo.packageName}\n";
  errorReport += "Installer Store: ${packageInfo.installerStore}\n";
  errorReport += "Build Signature: ${packageInfo.buildSignature}\n";
  errorReport += "[TIME]: $now\n";
  return errorReport;
}

/// Delete all user data and close/kill the app.
void forceReset() async {
  final directories = [
    await getApplicationDocumentsDirectory(),
    await getApplicationSupportDirectory(),
    await getApplicationCacheDirectory(),
    await getTemporaryDirectory(),
    await getDownloadsDirectory(),
  ];

  for (final directory in directories) {
    if (directory != null && directory.existsSync()) {
      try {
        await directory.delete(recursive: true);
      } catch (e) {
        logger.e("Failed to delete directory ${directory.path}: $e");
      }
    }
  }

  // Clear secure storage
  await FlutterSecretStore().deleteAll();

  // Stop the process emediately to avoid any further writes.
  exit(200);
}

void sendEmail(FlutterErrorDetails errorDetails) async {
  final errorReport = await generateErrorReport(errorDetails);

  final emailUri = Uri(
    scheme: 'mailto',
    path: 'lanis-mobile@alessioc42.dev',
    queryParameters: {
      'subject': '[FEHLERBERICHT] ${errorDetails.exceptionAsString()}',
      'body': '\n\n\n$errorReport',
    },
  );

  await safeLaunchUrl(emailUri);
}
