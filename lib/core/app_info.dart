import 'package:package_info_plus/package_info_plus.dart';

/// Static, synchronously-readable app version metadata. Populated once in
/// `main()` via [AppInfo.init].
class AppInfo {
  AppInfo._();

  static String _version = '1.0.0';
  static String _buildNumber = '1';

  static String get version => _version;
  static String get buildNumber => _buildNumber;
  static String get full => '$_version+$_buildNumber';

  static Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version.isEmpty ? _version : info.version;
      _buildNumber = info.buildNumber.isEmpty ? _buildNumber : info.buildNumber;
    } catch (_) {
      /* keep defaults — version metadata is non-critical */
    }
  }
}
