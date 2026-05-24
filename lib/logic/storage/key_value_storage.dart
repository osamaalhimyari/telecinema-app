/// Non-sensitive local key/value storage (display name, last-used reactions,
/// remembered room unlocks). Abstract so the rest of the app does not depend
/// on `shared_preferences` directly.
abstract class KeyValueStorage {
  String? getString(String key);
  Future<void> setString(String key, String value);
  bool? getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<void> remove(String key);
}
