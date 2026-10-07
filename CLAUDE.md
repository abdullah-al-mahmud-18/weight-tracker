# CLAUDE.md — Weight Tracker (Flutter, Android only)

## 1. Project summary

A simple, fully offline Android app for logging body weight.

- User logs weight (kg) any number of times per day; each entry is saved with the current timestamp.
- Home shows **today's average weight**.
- Optional height (feet + inches) enables a **BMI** page.
- History shows **daily averages for the last 30 days** and **monthly averages for the last 12 months**.
- User can **export** all entries to CSV in the phone's public **Downloads** folder and **import** entries from a CSV file.
- Clean, modern Material 3 UI.

Platform: **Android only**. Do not add iOS/web/desktop code or folders.

## 2. Tooling and environment

- Flutter **3.47.0** (stable). It bundles Dart 3.13.x. Keep the `environment.sdk` constraint that `flutter create` generates; do not hand-edit it to something else.
- Flutter 3.47 split Material into the standalone `material_ui` package. Follow whatever the 3.47 `flutter create` template uses. If the template imports `package:material_ui/material_ui.dart`, use that everywhere; do not mix it with `package:flutter/material.dart`. If unsure, run `dart fix --apply --code=migrate_design_widgets` after scaffolding.
- Create the project with:
  ```
  flutter create --platforms=android --org com.example weight_tracker
  ```
- Add dependencies with `flutter pub add <name>` (let pub resolve versions compatible with 3.47; do not hard-code versions from memory).

### Dependencies

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management |
| `sqflite` + `path` | Local SQLite storage |
| `shared_preferences` | Store height setting |
| `csv` | CSV encode/decode |
| `file_picker` | Pick CSV file for import |
| `intl` | Date/number formatting |
| `fl_chart` | Line chart on History page |
| `permission_handler` | Storage permission on Android 9 and below only |

Do not add any other packages without a clear reason. No networking, analytics, ads, or crash reporting. The release build must not require the `INTERNET` permission.

### Commands

```
flutter pub get
flutter analyze          # must be clean (zero warnings) before finishing a task
flutter test             # all tests must pass
flutter run              # on a connected device/emulator
flutter build apk --release
```

## 3. Architecture

Layered and small. Pure logic lives in `domain/` and is unit-tested without Flutter.

```
lib/
  main.dart                    # runApp(ProviderScope(child: App()))
  app.dart                     # MaterialApp, theme, bottom navigation shell
  core/
    theme.dart                 # light/dark ColorScheme.fromSeed
    formatters.dart            # weight, date, month formatting helpers
  domain/
    weight_entry.dart          # immutable model
    stats.dart                 # daily/monthly averaging (pure functions)
    bmi.dart                   # height conversion, BMI, category (pure)
    csv_codec.dart             # entries <-> CSV text (pure)
  data/
    app_database.dart          # sqflite open/migrations
    weight_repository.dart     # CRUD + range queries
    settings_repository.dart   # height via shared_preferences
  services/
    downloads_service.dart     # MethodChannel to native MediaStore code
    import_service.dart        # file_picker + csv_codec + repository
  providers/
    providers.dart             # Riverpod providers
  ui/
    home/home_page.dart
    history/history_page.dart
    bmi/bmi_page.dart
    data/data_page.dart        # export / import
    widgets/                   # shared widgets (stat card, empty state, etc.)
android/app/src/main/kotlin/<package path>/MainActivity.kt   # Downloads channel
test/
  stats_test.dart
  bmi_test.dart
  csv_codec_test.dart
```

Rules:
- UI never talks to sqflite directly; it goes through providers → repositories.
- After any insert/delete/import, invalidate the providers that depend on entries so every page refreshes.
- Keep widgets small; extract anything over ~150 lines.

## 4. Data model and storage

### SQLite table `entries`

```
id            INTEGER PRIMARY KEY AUTOINCREMENT
timestamp_ms  INTEGER NOT NULL   -- milliseconds since epoch, UTC
weight_kg     REAL    NOT NULL
UNIQUE(timestamp_ms, weight_kg)
```
Plus an index on `timestamp_ms`. DB version 1; write the open helper so future migrations are easy.

- Store time as UTC epoch ms. **All grouping by day/month uses the device's local time zone** (convert with `DateTime.fromMillisecondsSinceEpoch(ms).toLocal()` semantics).
- Store weight as entered (two decimal places max). Round only for display.

### Height (shared_preferences)

- Key `height_total_inches` (int). Absent = height not set.
- Input is feet (int) + inches (int). `totalInches = feet * 12 + inches`.

## 5. Features and exact behaviour

### 5.1 Navigation
Material 3 `NavigationBar` with four destinations: **Home**, **History**, **BMI**, **Data**.

### 5.2 Home page
- Top: a prominent card "Today's average" showing the average to up to 2 decimals (e.g. `72.43 kg`) and a subtitle like "from 5 entries". If no entries today: show "No entries today".
- Input: a numeric text field (decimal keyboard, suffix "kg") and an "Add" button. On submit, save `(now, weight)`, clear the field, show a short SnackBar, and update the average immediately.
- Validation: number, `20.0 ≤ weight ≤ 300.0`, max 2 decimal places (e.g. `88.65`). Accept both `.` and `,` as decimal separator. The field only lets the user type digits and a single separator (no letters or other symbols, no third decimal). Show inline error text, never crash.
- All weights and weight averages (Home, History, BMI) are displayed with up to 2 decimals (`0.0#`: `72.0`, `72.4`, `88.65`). The BMI value itself stays at 1 decimal.
- Below: list of today's entries (time `HH:mm` + weight), newest first. Swipe to delete with an "Undo" SnackBar. (Small addition so typos can be corrected.)

### 5.3 BMI page
- If height not set: empty state explaining BMI needs height, with a form: Feet (3–8) and Inches (0–11), both integers. Save to settings.
- If height set: show height (e.g. `5 ft 6 in`), an "Edit height" button, and the BMI card.
- Weight used for BMI: today's average if there are entries today; otherwise the daily average of the most recent day that has entries, with a note "Based on weight from <date>". If no entries at all: prompt the user to log a weight first.
- Formula:
  ```
  heightMeters = totalInches * 0.0254
  bmi          = weightKg / (heightMeters * heightMeters)
  ```
  Display to 1 decimal. Sanity check: 70 kg, 5 ft 6 in → 66 in → 1.6764 m → BMI 24.9.
- Category (WHO adult), evaluated on the **rounded 1-decimal value** so label and number always agree:
  - `< 18.5` Underweight
  - `18.5 – 24.9` Normal
  - `25.0 – 29.9` Overweight
  - `≥ 30.0` Obese
- Show a simple horizontal colour scale with a marker for the user's position.

### 5.4 History page
A `SegmentedButton` switches between **Daily (30 days)** and **Monthly (12 months)**. Each view has a line chart (fl_chart) on top and a list below.

Definitions (implement in `domain/stats.dart`):
- **Daily average** = arithmetic mean of all entries whose local date is that day.
- **Last 30 days** = today plus the previous 29 local calendar days. Show only days that have entries. List newest first; chart oldest → newest.
- **Monthly average** = mean of the **daily averages** of that month (so a day with many weigh-ins does not dominate). Use this definition consistently.
- **Last 12 months** = current month plus the previous 11 calendar months. Show only months that have entries.
- Day boundaries: local midnight to next local midnight. Month boundaries: local first day 00:00 to first day of next month 00:00. Use calendar arithmetic (`DateTime(y, m, d)`), not `Duration(days: 30)`, so DST shifts never break grouping.
- Empty state when there is no data in the range.

### 5.5 Data page (export / import)

**CSV format** (UTF-8, comma-separated, header required):
```
timestamp,weight_kg
2026-10-03T08:15:00+06:00,72.4
```
- `timestamp`: ISO 8601 local time **with explicit UTC offset** (`+06:00`). Dart's `toIso8601String()` omits the offset for local times, so write a small custom formatter in `csv_codec.dart`.
- `weight_kg`: number with `.` decimal separator.
- Height is a setting, not data; it is not exported.

**Export**
- Button "Export to Downloads". Writes all entries (oldest first) to `weight_tracker_YYYYMMDD_HHmmss.csv` in the public Downloads folder via the native channel (section 6). Show a SnackBar with the file name on success, a clear error on failure.

**Import**
- Button "Import from CSV". Use `file_picker` with `FileType.custom, allowedExtensions: ['csv']`, `withData: true` (read bytes, not a path). If the picker misbehaves with CSV MIME types on some devices, fall back to `FileType.any` and check the extension yourself.
- Parsing: header row must contain `timestamp` and `weight_kg` (case-insensitive, any column order). Timestamps with an offset are parsed with `DateTime.parse` and converted to UTC; timestamps without an offset are treated as local time.
- Rows with unparsable timestamp or weight outside 20–300 kg are skipped, not fatal.
- Merge mode: insert with `INSERT OR IGNORE` (UNIQUE constraint handles duplicates). Run all inserts in a single transaction.
- Show a result dialog: "Imported X · Skipped Y duplicates · Z invalid rows".
- Re-importing a file produced by Export must import 0 new rows (round-trip must be lossless at millisecond precision — include milliseconds in the timestamp if non-zero).

## 6. Android: saving to the public Downloads folder

Implement natively; do not rely on `path_provider` (its directories are app-private).

MethodChannel name: `weight_tracker/downloads`, method `saveCsv(fileName: String, content: String) → String` (returns the saved display name).

In `MainActivity.kt`:
- **Android 10+ (API 29+)**: insert into `MediaStore.Downloads.EXTERNAL_CONTENT_URI` with `DISPLAY_NAME`, `MIME_TYPE = "text/csv"`, `RELATIVE_PATH = Environment.DIRECTORY_DOWNLOADS`, `IS_PENDING = 1`; write via `contentResolver.openOutputStream(uri)`; then set `IS_PENDING = 0`. No permission needed.
- **Android 9 and below (API ≤ 28)**: write to `Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)`. Requires `WRITE_EXTERNAL_STORAGE`; declare it in the manifest with `android:maxSdkVersion="28"` and request it at runtime via `permission_handler` only on those versions.
- Return errors through `result.error(...)`; the Dart side converts them into user-friendly messages.

Keep `minSdk` at the Flutter template default.

## 7. UI / design guidelines

- Material 3, `ColorScheme.fromSeed(seedColor: Colors.teal)`, light and dark themes following the system setting.
- Generous spacing (16 dp page padding), rounded cards, large readable numbers for the headline stats (`displaySmall`/`headlineMedium`).
- Use `intl` for dates: daily list `EEE, d MMM` (e.g. `Sat, 3 Oct`), monthly list `MMMM yyyy`.
- Every page has a friendly empty state (icon + one line of text).
- No hard-coded colours in widgets; take them from `Theme.of(context).colorScheme`.
- Keyboard: dismiss on submit; the Add button is disabled while input is empty.
- App name shown on the launcher: "Weight Tracker".

## 8. Testing requirements

Unit tests (no device needed):
- `stats_test.dart`: multiple entries in one day average correctly; entries at 23:59 and 00:01 land in different days; 30-day window includes today and excludes day 31; monthly average is the mean of daily averages; empty input returns empty results.
- `bmi_test.dart`: 5 ft 6 in → 66 in → 1.6764 m; 70 kg → 24.9 Normal; category boundaries at 18.5, 25.0, 30.0 using the rounded value.
- `csv_codec_test.dart`: export → import round trip is lossless; header order independence; rows with bad data are counted as invalid; offset and no-offset timestamps both parse.

## 9. Working rules for Claude

- Build in this order: scaffold → domain + tests → database/repositories → Home → History → BMI → Data/export/import → native Downloads channel → polish UI.
- After each step run `flutter analyze` and `flutter test`; fix issues before moving on.
- Keep the scope as written. Do not add accounts, cloud sync, notifications, or goal tracking unless asked.
- Never silently change a definition in section 5 (averages, windows, BMI formula, CSV format). If something is ambiguous, ask.
- Prefer clear, readable code over clever code; add short doc comments to public functions in `domain/`.