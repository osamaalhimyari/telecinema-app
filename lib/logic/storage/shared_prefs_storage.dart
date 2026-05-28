import 'package:shared_preferences/shared_preferences.dart';

import 'key_value_storage.dart';

class SharedPrefsStorage implements KeyValueStorage {
  SharedPrefsStorage(this._prefs);

  final SharedPreferences _prefs;

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

/// Well-known storage keys, centralized so they cannot drift.
class StorageKeys {
  StorageKeys._();
  static const displayName = 'display_name';
  static const serverBaseUrl = 'server_base_url';
  static String roomUnlocked(String slug) => 'room_unlocked_$slug';
}
