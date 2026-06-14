import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

/// Hands a downloaded APK to the Android package installer.
///
/// Android 8+ requires the user to grant our app the "install unknown apps"
/// special permission first; we request it, then open the APK. `open_filex`
/// ships its own FileProvider, so the installer can read the file via a
/// content:// URI without us declaring one.
class ApkInstaller {
  const ApkInstaller();

  /// Returns true if the installer was launched, false if the user declined the
  /// "install unknown apps" permission (so the caller can prompt again).
  Future<bool> install(String apkPath) async {
    if (!await Permission.requestInstallPackages.isGranted) {
      final result = await Permission.requestInstallPackages.request();
      if (!result.isGranted) return false;
    }

    final res = await OpenFilex.open(
      apkPath,
      type: 'application/vnd.android.package-archive',
    );
    return res.type == ResultType.done;
  }
}
