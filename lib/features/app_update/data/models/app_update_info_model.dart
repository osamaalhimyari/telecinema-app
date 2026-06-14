import '../../domain/entities/app_update_info.dart';

/// Parses the `data` envelope of `GET /api/app/version` into [AppUpdateInfo].
/// Shape: `{ updateAvailable, forced, latest: { versionName, versionCode,
/// releaseNotes, fileSize, downloadPath, downloadUrl } | null }`.
class AppUpdateInfoModel {
  const AppUpdateInfoModel._();

  static AppUpdateInfo fromJson(Map<String, dynamic> json) {
    final rawLatest = json['latest'];
    final latest = rawLatest is Map<String, dynamic> ? rawLatest : const <String, dynamic>{};

    return AppUpdateInfo(
      updateAvailable: json['updateAvailable'] == true,
      forced: json['forced'] == true,
      versionName: latest['versionName']?.toString(),
      versionCode: _int(latest['versionCode']),
      releaseNotes: latest['releaseNotes']?.toString(),
      fileSize: _int(latest['fileSize']),
      downloadPath: latest['downloadPath']?.toString(),
    );
  }

  static int? _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }
}
