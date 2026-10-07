import 'package:shared_preferences/shared_preferences.dart';

/// Persists user settings (currently only height).
class SettingsRepository {
  static const String heightKey = 'height_total_inches';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  /// Height in total inches, or `null` if not set.
  Future<int?> getHeightInches() => _prefs.getInt(heightKey);

  Future<void> setHeightInches(int totalInches) =>
      _prefs.setInt(heightKey, totalInches);
}
