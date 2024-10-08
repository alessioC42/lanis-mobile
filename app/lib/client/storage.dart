import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StorageKey {
  settingsPushService,
  settingsPushServiceIntervall,
  settingsPushServiceOngoing,
  settingsSelectedColor,
  settingsSelectedTheme,
  settingsIsAmoled,

  userSchoolID,
  userUsername,
  userPassword,
  userSchoolName,
  userData,

  substitutionsFilter,

  lastPushMessageHash,
  lastAppVersion,
  schoolImageLocation,
  schoolLogoLocation,
  schoolAccentColor,

  //these keys store JSON strings containing the serialised Fetcher Data for offline use
  lastSubstitutionData,
  lastTimetableData,
}

extension on StorageKey {
  String get key {
    switch (this) {
      case StorageKey.settingsPushService:
        return "settings-push-service-on";
      case StorageKey.settingsPushServiceIntervall:
        return "settings-push-service-interval";
      case StorageKey.settingsPushServiceOngoing:
        return "settings-push-service-notifications-ongoing";
      case StorageKey.userSchoolID:
        return "schoolID";
      case StorageKey.lastAppVersion:
        return "last-app-version";
      case StorageKey.userUsername:
        return "username";
      case StorageKey.userPassword:
        return "password";
      case StorageKey.userSchoolName:
        return "schoolName";
      case StorageKey.userData:
        return "userData";
      case StorageKey.schoolImageLocation:
        return "schoolImageLocation";
      case StorageKey.schoolLogoLocation:
        return "schoolLogoLocation";
      case StorageKey.schoolAccentColor:
        return "schoolColor";
      case StorageKey.settingsSelectedColor:
        return "color";
      case StorageKey.settingsSelectedTheme:
        return "theme";
      case StorageKey.settingsIsAmoled:
        return "isAmoled";
      case StorageKey.lastPushMessageHash:
        return "last-notifications-hash";
      case StorageKey.substitutionsFilter:
        return "{}"; // that should be "substitutions-filter". Keeping it due to user consistency because changing would result in a clear of the filter
      case StorageKey.lastSubstitutionData:
        return "last-substitution-data";
      case StorageKey.lastTimetableData:
        return "last-timetable-data-both";
    }
  }

  String get defaultValue {
    switch (this) {
      case StorageKey.settingsPushService:
        return "true";
      case StorageKey.settingsPushServiceIntervall:
        return "15";
      case StorageKey.lastAppVersion:
        return "0.0.0";
      case StorageKey.userData:
        return "{}";
      case StorageKey.settingsPushServiceOngoing:
        return "false";
      case StorageKey.settingsSelectedColor:
        return "standard";
      case StorageKey.settingsSelectedTheme:
        return "system";
      case StorageKey.settingsIsAmoled:
        return "false";

      default:
        return "";
    }
  }
}

class Storage {
  SharedPreferences? prefs;
  final secureStorage =
      const FlutterSecureStorage(aOptions: AndroidOptions.defaultOptions);

  Future<void> initialize() async {
    prefs ??= await SharedPreferences.getInstance();
  }

  AndroidOptions _getAndroidOptions() => const AndroidOptions(
        encryptedSharedPreferences: true,
      );

  Future<void> write({
    required StorageKey key,
    required String value,
    bool secure = false,
  }) async {
    await initialize();

    if (secure) {
      await secureStorage.write(
        key: key.key,
        value: value,
        aOptions: _getAndroidOptions(),
      );
    } else {
      await prefs!.setString(key.key, value);
    }
  }

  Future<String> read({required StorageKey key, secure = false}) async {
    await initialize();

    if (secure) {
      return Future.value((await secureStorage.read(
              key: key.key, aOptions: _getAndroidOptions())) ??
          key.defaultValue);
    } else {
      return Future.value(prefs!.getString(key.key) ?? key.defaultValue);
    }
  }

  Future<void> deleteAll() async {
    await initialize();

    await prefs!.clear();
    await secureStorage.deleteAll(aOptions: _getAndroidOptions());
  }
}

Storage globalStorage = Storage();
