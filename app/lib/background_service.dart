import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sph_plan/client/client_submodules/substitutions.dart';
import 'package:workmanager/workmanager.dart';

import 'client/client.dart';
import 'client/logger.dart';
import 'client/storage.dart';

Future<void> setupBackgroundService() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  bool enableNotifications =
      await globalStorage.read(key: StorageKey.settingsPushService) ==
          "true";

  PermissionStatus? notificationsPermissionStatus;

  await Permission.notification.isDenied.then((value) async {
    if (value) {
      notificationsPermissionStatus =
      await Permission.notification.request();
    }
  });
  if ((notificationsPermissionStatus ?? PermissionStatus.granted).isGranted && enableNotifications) return;

  await Workmanager().cancelAll();

  await Workmanager().initialize(callbackDispatcher,
      isInDebugMode: kDebugMode);
  const uniqueName = "notificationservice";
  final constraints = Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: true,
      requiresCharging: false,
      requiresDeviceIdle: false,
      requiresStorageNotLow: false
  );

  if (Platform.isAndroid) {
    int notificationInterval = int.parse(await globalStorage.read(
        key: StorageKey.settingsPushServiceIntervall));

    await Workmanager().registerPeriodicTask(uniqueName, uniqueName,
        frequency: Duration(minutes: notificationInterval),
        constraints: constraints,
        initialDelay: const Duration(minutes: 3)
    );

  }
  if (Platform.isIOS) {
    logger.i("iOS detected, using one-off task");
    try {
      String executionTime = await globalStorage.read(
          key: StorageKey.settingsPushServiceIOSTime);
      final timeList = executionTime.split(":");
      TimeOfDay time = TimeOfDay(hour: int.parse(timeList[0]), minute: int.parse(timeList[1]));
      DateTime now = DateTime.now();
      DateTime scheduledTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);

      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      while (scheduledTime.weekday == DateTime.saturday || scheduledTime.weekday == DateTime.sunday) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      await Workmanager().registerOneOffTask(uniqueName, uniqueName,
        constraints: constraints,
        initialDelay: scheduledTime.difference(now),
      );
    } catch (e, s) {
      logger.e(e, stackTrace: s);
    }
  }
}

Future<void> initializeNotifications() async {
  FlutterLocalNotificationsPlugin().initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@drawable/ic_launcher'),
      iOS: DarwinInitializationSettings(
        onDidReceiveLocalNotification: onDidReceiveLocalNotification,
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true
      )
    ),
  );
}

void onDidReceiveLocalNotification(
    int id, String? title, String? body, String? payload) {
  logger.i("Received local notification with id $id, title $title, body $body, payload $payload");
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      logger.i("Background fetch triggered");
      await updateNotifications();
      return Future.value(true);
    } catch (e) {
      logger.f(e.toString());
    }
    return Future.value(true);
  });
}

Future<void> updateNotifications() async {
  initializeNotifications();
  var client = SPHclient();
  await client.prepareDio();
  await client.loadFromStorage();
  if (client.username == "" || client.password == "") {
    logger.w("No credentials found, aborting background fetch");
  }
  await client.login(backgroundFetch: true);
  final vPlan =
  await client.substitutions.getAllSubstitutions(skipLoginCheck: true, filtered: true);
  await globalStorage.write(
      key: StorageKey.lastSubstitutionData, value: jsonEncode(vPlan));
  List<Substitution> allSubstitutions = vPlan.allSubstitutions;
  String messageBody = "";

  for (final entry in allSubstitutions) {
    final time =
        "${weekDayGer(entry.tag)} ${entry.stunde.replaceAll(" - ", "/")}";
    final type = entry.art ?? "";
    final subject = entry.fach ?? "";
    final teacher = entry.lehrer ?? "";
    final classInfo = entry.klasse ?? "";

    // Concatenate non-null values with separator "-"
    final entryText = [time, type, subject, teacher, classInfo]
        .where((e) => e.isNotEmpty)
        .join(" - ");

    messageBody += "$entryText\n";
  }

  if (messageBody != "") {
    final messageUUID = generateUUID(messageBody);

    messageBody +=
    "Zuletzt editiert: ${DateFormat.Hm().format(vPlan.lastUpdated)}";

    if (!(await isMessageAlreadySent(messageUUID))) {
      await sendMessage(
          "${allSubstitutions.length} Einträge im Vertretungsplan",
          messageBody);
      await markMessageAsSent(messageUUID);
    }
  }
}

Future<void> sendMessage(String title, String message, {int id = 0}) async {
  try {
    bool ongoingMessage =
      (await globalStorage.read(key: StorageKey.settingsPushServiceOngoing)) ==
          "true";

  final androidDetails = AndroidNotificationDetails(
      'io.github.alessioc42.sphplan', 'lanis-mobile',
      channelDescription: "Benachrichtigungen über den Vertretungsplan",
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(message),
      ongoing: ongoingMessage,
      );
  const iOSDetails = DarwinNotificationDetails(
      presentAlert: false, presentBadge: true,
      
  );
  var platformDetails = NotificationDetails(android: androidDetails, iOS: iOSDetails);
  await FlutterLocalNotificationsPlugin()
      .show(id, title, message, platformDetails);
  } catch (e,s) {
    logger.e(e, stackTrace: s);
  }
}

String generateUUID(String input) {
  // Use a hash function (MD5) to generate a unique identifier for the message
  final uuid = crypto.md5.convert(utf8.encode(input)).toString();
  return uuid;
}

Future<void> markMessageAsSent(String uuid) async {
  await globalStorage.write(key: StorageKey.lastPushMessageHash, value: uuid);
}

Future<bool> isMessageAlreadySent(String uuid) async {
  // Read the existing JSON from secure storage
  String storageValue =
  await globalStorage.read(key: StorageKey.lastPushMessageHash);
  return storageValue == uuid;
}

String weekDayGer(String dateString) {
  final inputFormat = DateFormat('dd.MM.yyyy');
  final dateTime = inputFormat.parse(dateString);

  final germanFormat = DateFormat('E', 'de');
  return germanFormat.format(dateTime);
}
