import 'package:equatable/equatable.dart';

/// The server's answer to "is there a newer build?". Mirrors the JSON returned
/// by `GET /api/app/version` on the AdonisJS backend.
class AppUpdateInfo extends Equatable {
  const AppUpdateInfo({
    required this.updateAvailable,
    required this.forced,
    this.versionName,
    this.versionCode,
    this.releaseNotes,
    this.fileSize,
    this.downloadPath,
  });

  /// True when the latest published build is newer than this install.
  final bool updateAvailable;

  /// True when the user must update before continuing (mandatory build, or the
  /// current build has been blocked server-side). The UI shows a blocking gate.
  final bool forced;

  final String? versionName;
  final int? versionCode;
  final String? releaseNotes;

  /// Size of the APK in bytes — drives the download progress bar.
  final int? fileSize;

  /// Server-relative download path (e.g. `/api/app/download/12`). Joined onto
  /// the app's configured server origin so an overridden server still works.
  final String? downloadPath;

  /// The "no update" answer.
  static const none = AppUpdateInfo(updateAvailable: false, forced: false);

  @override
  List<Object?> get props => [
    updateAvailable,
    forced,
    versionName,
    versionCode,
    releaseNotes,
    fileSize,
    downloadPath,
  ];
}
