# Lanis Mobile

*[Read this in English](README.en.md)*

Deine App für das hessische Schulportal! In Zusammenarbeit mit dem staatlichen Schulamt für den Landkreis Groß-Gerau und den Main-Taunus-Kreis
**Einsatz an zahlreichen Schulen in Hessen mit über 45 Tausend täglichen Nutzern.**

<p align="center">
    <img src="https://github.com/alessioC42/lanis-mobile/assets/84250128/19d30436-32f7-4cbe-b78e-f2fee3583c28" width="60%">
</p>

<table>
    <tr>
        <td colspan='2'>
            <a href='https://play.google.com/store/apps/details?id=io.github.alessioc42.sph&pcampaignid=pcampaignidMKT-Other-global-all-co-prtnr-py-PartBadge-Mar2515-1'><img alt='Jetzt bei Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/de_badge_web_generic.png' style='height: 71px'/></a>
        </td>
        <td colspan='2'>
            <a href="https://apt.izzysoft.de/fdroid/index/apk/io.github.alessioc42.sph"><img src="https://www.martinstoeckli.ch/images/izzy-on-droid-badge-en.png" alt="Get it on IzzyOnDroid" style="height: 56px;"></a>
        </td>
        <td colspan='2'>
            <a href='https://apps.apple.com/de/app/lanis-mobile/id6511247743?l=en-GB'><img alt='Jetzt im App Store' src='https://lanis-mobile.github.io/assets/ios-badge.svg' style='height: 61px'/></a>
        </td>
    </tr>
    <tr>
        <td colspan='3'>
            <a href='https://lanis-mobile.github.io/'>Website</a>
        </td>
        <td colspan='3'>
            <a href='https://discord.gg/MGYaSetUsY'>Discord</a>
        </td>
    </tr>
</table>

<p></p>
<details>
  <summary>Screenshots</summary>
<div style="text-align: center;">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/01.png" width="250" >
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/02.png" width="250" >
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/03.png" width="250" >
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/04.png" width="250" >
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/05.png" width="250" >
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/06.png" width="250" >
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/07.png" width="250" >

</div>
</details>

## Mitarbeit
Dieses Projekt ist stark von Bug-Reports anderer Schulen oder von neuen Mitarbeitern abhängig. Der Grund dafür liegt in
der modularen Natur des Schulportals, die es äußerst schwierig macht, eine universelle Lanis-App zu entwickeln.

Scheue dich nicht, einen Bug-Report zu erstellen, wenn du einen Fehler findest. Wir sind immer offen für neue Mitarbeiter/Schüler, die mit uns arbeiten, um die App zu verbessern.

Bug-Reports können auch an <a href="mailto:lanis-mobile@alessioc42.dev">diese</a> E-Mail-Adresse gesendet werden, falls kein Github-Konto vorhanden ist.

## Erste Schritte für die Entwicklung
### 1. [Flutter einrichten](https://docs.flutter.dev/get-started/quick) mit deiner bevorzugten IDE (Android Studio / VScode empfohlen)

### 2. Code generieren
```shell
dart run build_runner build # Datenbank
dart run intl_utils:generate # Lokalisierungen
```
### 3. Entwicklung
Beachte hierbei folgende Flags:
#### `--dart-define=cronetHttpNoPlay=true`
**[Teilweise optional]**
Dieses Flag wird verwendet, um die Cronet-Binärdatei für das Networking auf Geräten ohne Play Services einzubinden (diese Version stellen wir auch im Play Store bereit).

Falls du aktuell das Standard-Android-Emulator-Image verwendest, solltest du stattdessen ein AOSP-Image nutzen, da diese in der Regel deutlich performanter sind als Versionen mit Play Services.

Bei iOS-Builds ist dieses Flag nicht erforderlich.

#### `--dart-define=ANSI=true`
**[Optional]**
Dieses Flag ermöglicht farbige Logs der Anwendung, was sehr hilfreich sein kann, falls du noch nicht die Log-Filter-Tools deiner IDE nutzt. (Auf macOS wird empfohlen, dieses Flag wegzulassen, da das Standard-Terminal dies nicht unterstützt.)

```shell
flutter run --dart-define=cronetHttpNoPlay=true --dart-define=ANSI=true
```

### 4. Produktion
Für den tatsächlichen Release-Modus ist eine Signierung erforderlich. Dafür müssen die entsprechenden Dateien `key.properties` und `local.properties` im `android`-Verzeichnis abgelegt werden. Bei iOS muss in Xcode das Development Team geändert werden.

Falls du einen Build erstellst, den du an andere Personen weitergeben möchtest, ändere bitte die App-ID von `io.github.alessioc42.sph` in `io.github.alessioc42.sph.<fork|dev>.<DEIN_NAME>` oder einen anderen Namen, der sich von der Original-App-ID unterscheidet. Dies verhindert Konflikte mit den von uns veröffentlichten Store-Versionen.

```shell
flutter build <apk|aab|ipa> --release --dart-define=cronetHttpNoPlay=true
```

Alternativ gibt es das interaktive Skript `build.py`, das Android und/oder iOS in einem Durchlauf bauen, die Artefakte nach `artifacts/` kopieren und optional zu App Store Connect / Google Play hochladen kann:

```shell
python3 build.py
# oder nicht-interaktiv:
python3 build.py --android --ios --skip-upgrade --yes
```

#### Store-Uploads (optional)

`build.py` lädt Zugangsdaten aus den (per `.gitignore` ausgeschlossenen) Dateien `.env` / `.build.env` im Repository-Root (echte Umgebungsvariablen haben Vorrang). Beispiel:

```env
ASC_API_KEY_ID=XXXXXXXXXX
ASC_API_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ASC_API_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8
PLAY_SERVICE_ACCOUNT_JSON=/path/to/service-account.json
```

Zusätzliche Datei: `python3 build.py --env-file /path/to/secrets.env`.

Für Play-Uploads installiere die optionalen Python-Abhängigkeiten und verwende ein Google-Cloud-Service-Konto, das in der Play Console (Nutzer und Berechtigungen) mit der Berechtigung zur Verwaltung von Tracks eingeladen wurde:

```shell
pip install -r requirements-build.txt
python3 build.py --android --upload-android --play-track internal --yes
```

Für App-Store-Connect-Uploads (macOS + Xcode) erstelle einen App Store Connect API-Key, trage die Werte in `.env` ein (oder exportiere sie) und führe dann aus:

```shell
python3 build.py --ios --upload-ios --yes
```

Uploads liefern lediglich die Binärdatei aus (TestFlight / Play-Track). Sie reichen den Build nicht zur App-Review ein und geben kein Produktions-Rollout frei.
