# Lanis Mobile

*[Auf Deutsch lesen](README.md)*

Your app for the Hessian school portal! In cooperation with the staatliches Schulamt für den Landkreis Groß-Gerau und den Main-Taunus-Kreis.
**In use at numerous schools in Hesse with over 45 thousand daily users.**

<p align="center">
    <img src="https://github.com/alessioC42/lanis-mobile/assets/84250128/19d30436-32f7-4cbe-b78e-f2fee3583c28" width="60%">
</p>

<table>
    <tr>
        <td colspan='2'>
            <a href='https://play.google.com/store/apps/details?id=io.github.alessioc42.sph&pcampaignid=pcampaignidMKT-Other-global-all-co-prtnr-py-PartBadge-Mar2515-1'><img alt='Get it on Google Play' src='https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png' style='height: 71px'/></a>
        </td>
        <td colspan='2'>
            <a href="https://apt.izzysoft.de/fdroid/index/apk/io.github.alessioc42.sph"><img src="https://www.martinstoeckli.ch/images/izzy-on-droid-badge-en.png" alt="Get it on IzzyOnDroid" style="height: 56px;"></a>
        </td>
        <td colspan='2'>
            <a href='https://apps.apple.com/de/app/lanis-mobile/id6511247743?l=en-GB'><img alt='Download on the App Store' src='https://lanis-mobile.github.io/assets/ios-badge.svg' style='height: 61px'/></a>
        </td>
    </tr>
    <tr>
        <td colspan='3'>
            <a href='https://lanis-mobile.github.io/'>website</a>
        </td>
        <td colspan='3'>
            <a href='https://discord.gg/MGYaSetUsY'>discord</a>
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

## Contributing
This project relies heavily on bug reports from other schools and on new contributors. The reason for this lies in
the modular nature of the school portal, which makes it extremely difficult to develop a universal Lanis app.

Don't hesitate to open a bug report if you find an issue. We're always open to new contributors/students working with us to improve the app.

Bug reports can also be sent to <a href="mailto:lanis-mobile@alessioc42.dev">this</a> email address if you don't have a GitHub account.

## Get started with development
### 1. [Setup Flutter](https://docs.flutter.dev/get-started/quick) with your favourite IDE (Android Studio / VScode recommended)

### 2. Generate the code
```shell
dart run build_runner build # Database
dart run intl_utils:generate # Localisations
```
### 3. Development
Note the flags here:
#### `--dart-define=cronetHttpNoPlay=true`
**[Partially optional]**
This flag is used to include the Cronet binary for networking on non-Play-Services-enabled devices (we also ship this version on the Play Store).

If you are currently using the default Android emulator image, consider using an AOSP image instead, as these tend to perform much better than versions with Play Services enabled.

On iOS builds this flag is not required.

#### `--dart-define=ANSI=true`
**[Optional]**
This flag allows the application's logs to be colorized, which can help a lot if you are not already using your IDE's log-filtering tools. (Recommended to omit on macOS due to lack of support in the default Terminal.)

```shell
flutter run --dart-define=cronetHttpNoPlay=true --dart-define=ANSI=true
```

### 4. Production
For actual release mode signing is required, which can be added via placing the respective `key.properties` and `local.properties` in the `android` directory. On iOS the Development team has to be changed in Xcode.

If you are producing a build that you intend to distribute to other people, please consider changing the app ID from `io.github.alessioc42.sph` to `io.github.alessioc42.sph.<fork|dev>.<YOUR_NAME>` or any other name that is different from the original app ID. This will prevent conflicts with the store versions that we are publishing.

```shell
flutter build <apk|aab|ipa> --release --dart-define=cronetHttpNoPlay=true
```

An alternative is the interactive `build.py` script, which can build Android and/or iOS in one run, copy artifacts into `artifacts/`, and optionally upload to App Store Connect / Google Play:

```shell
python3 build.py
# or non-interactive:
python3 build.py --android --ios --skip-upgrade --yes
```

#### Store uploads (optional)

`build.py` loads secrets from gitignored `.env` / `.build.env` in the repo root (real environment variables win). Example:

```env
ASC_API_KEY_ID=XXXXXXXXXX
ASC_API_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ASC_API_KEY_PATH=/path/to/AuthKey_XXXXXXXXXX.p8
PLAY_SERVICE_ACCOUNT_JSON=/path/to/service-account.json
```

Extra file: `python3 build.py --env-file /path/to/secrets.env`.

For Play uploads, install the optional Python deps and use a Google Cloud service account that has been invited in Play Console (Users and permissions) with permission to manage tracks:

```shell
pip install -r requirements-build.txt
python3 build.py --android --upload-android --play-track internal --yes
```

For App Store Connect uploads (macOS + Xcode), create an App Store Connect API key, put the values in `.env` (or export them), then:

```shell
python3 build.py --ios --upload-ios --yes
```

Uploads deliver the binary only (TestFlight / Play track). They do not submit for App Review or promote a production rollout.
