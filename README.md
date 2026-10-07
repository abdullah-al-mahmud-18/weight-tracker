# Weight Tracker

A simple, fully offline Android app for logging body weight. Built with
Flutter and Material 3.

Everything stays on the device: no account, no network access (the release
build does not request the `INTERNET` permission), no analytics or ads.

> **Vibe coded by Claude.** This app was built by
> [Claude Code](https://claude.com/claude-code) (Anthropic's AI coding agent)
> from the specification in [`CLAUDE.md`](CLAUDE.md), with the author
> directing the work.

## Features

- **Quick logging.** Enter your weight in kg and tap **Add**. Log as many times
  a day as you like; each entry is saved with the current time. Both `.` and
  `,` work as the decimal separator. Values must be 20–300 kg with at most one
  decimal place.
- **Today's average.** The Home page shows the average of today's entries and
  how many there are, plus a list of today's entries (newest first). Swipe an
  entry left to delete it, with **Undo**.
- **History.** Switch between:
  - **Daily (30 days)**: the average for each day with entries, today plus the
    previous 29 days.
  - **Monthly (12 months)**: the current month plus the previous 11. A month's
    value is the mean of its *daily* averages, so a day with many weigh-ins
    doesn't outweigh the others.

  Each view has a line chart (oldest → newest) and a list (newest first).
  Days and months follow the phone's local time zone and are unaffected by
  daylight-saving changes.
- **BMI.** Enter your height in feet and inches (3–8 ft, 0–11 in) to see your
  BMI, its WHO adult category (Underweight, Normal, Overweight, Obese) and a
  colour scale showing where you are. BMI uses today's average, or the most
  recent day with entries (the page says which date).
- **Export.** Save all entries as a CSV file in the phone's public
  **Downloads** folder, named `weight_tracker_YYYYMMDD_HHmmss.csv`.
- **Import.** Load entries from a CSV file. Imported entries are merged with
  existing ones; exact duplicates (same time and weight) are skipped, and rows
  with bad data are skipped rather than stopping the import. A summary shows
  how many rows were imported, duplicated and invalid. Re-importing a file
  exported by the app adds nothing new.
- **Light and dark themes** that follow the system setting.

## CSV format

UTF-8, comma-separated, with a header row:

```csv
timestamp,weight_kg
2026-10-03T08:15:00+06:00,72.4
2026-10-03T20:01:02.345+06:00,73.0
```

- `timestamp`: ISO 8601 local time with its UTC offset. Milliseconds appear
  only when non-zero. On import, a timestamp without an offset is treated as
  the phone's local time.
- `weight_kg`: number with `.` as the decimal separator, 20–300.
- Column order and header case don't matter on import; extra columns are
  ignored.
- Height is a setting, not data, so it is not exported.

## Requirements

- Flutter **3.47.0** (stable, Dart 3.13). On this machine it is installed with
  FVM at `~/fvm/versions/stable` and is not on `PATH`; the scripts and VS Code
  settings below find it automatically.
- Android SDK with **platform 37** (`permission_handler_android` 14.x needs
  `compileSdk = 37`; `minSdk` and `targetSdk` are the Flutter defaults).
- An Android device or emulator. The scripts and VS Code config expect an AVD
  named `medium_phone`.

Android is the only supported platform.

## Running and debugging

**VS Code** (Dart and Flutter extensions required): open the Run and Debug
panel and pick:

- **Weight Tracker (debug, emulator)**: builds a debug APK, boots the
  `medium_phone` emulator if needed, then launches with the debugger attached.
- **Weight Tracker (debug, selected device)**: launches on the device selected
  in the status bar, e.g. a phone connected over USB.

`.vscode/settings.json` points the Dart extension at the FVM SDK. The path is
absolute, so change `dart.flutterSdkPath` if your SDK lives elsewhere.

**Command line:**

```bash
scripts/build_and_start_emulator.sh   # build debug APK, boot emulator, wait until ready
~/fvm/versions/stable/bin/flutter run
```

## Building a release

```bash
scripts/build_release.sh
```

This builds obfuscated, shrunk release APKs, one per CPU type, in
`build/app/outputs/flutter-apk/`. For a phone, install
`app-arm64-v8a-release.apk`:

```bash
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Debug symbols are written to `build/symbols`. Keep them for each release you
distribute, as you need them to read obfuscated crash stack traces
(`flutter symbolize`).

Both scripts pick Flutter in this order: the `FLUTTER` environment variable,
`fvm flutter` if the project has a `.fvmrc`, the FVM `stable` SDK, then
`flutter` on `PATH`.

## App icon and splash screen

The source icon is `assets/app_icon.png`. The launcher icons (adaptive icon
with a themed-icon layer, plus a legacy icon for Android 7) and the splash
screen image are generated from it into `android/app/src/main/res/`:

```bash
python3 scripts/generate_icons.py   # needs Pillow
```

Re-run it after replacing the source icon. If the new icon has a different
background colour, also update `android/app/src/main/res/values/colors.xml`
and `BACKGROUND` in the script. The splash uses the native Android 12+ splash
API (`values-v31`, `values-night-v31`) and a layer-list drawable on older
versions (`drawable`, `drawable-night`). In dark mode the icon is shown on an
off-white circle.

## Testing

```bash
~/fvm/versions/stable/bin/flutter analyze   # must report no issues
~/fvm/versions/stable/bin/flutter test
```

Unit tests cover the averaging rules (day and month boundaries, the 30-day and
12-month windows), BMI maths and categories, weight input validation, and the
CSV round trip and error handling. Grouping depends on the time zone, so it's
worth also running the tests under a zone with daylight saving, e.g.
`TZ=America/New_York flutter test`.

## Project structure

```
lib/
  main.dart, app.dart     App entry, theme, bottom navigation
  core/                   Theme and formatting helpers
  domain/                 Pure logic: model, averages, BMI, CSV (unit-tested)
  data/                   SQLite database and repositories, height setting
  services/               Downloads (native channel) and CSV import
  providers/              Riverpod providers
  ui/                     Home, History, BMI and Data pages, shared widgets
android/app/src/main/kotlin/.../MainActivity.kt
                          Saves exports to Downloads (MediaStore on Android 10+,
                          public folder with storage permission on 9 and below)
scripts/                  Emulator, release build and icon generation scripts
assets/app_icon.png       Source app icon
test/                     Unit tests
```

Entries are stored in SQLite (`entries` table, UTC timestamps in
milliseconds); height is stored with `shared_preferences`. `CLAUDE.md` has the
full specification.

## License

Released under the [MIT License](LICENSE).
