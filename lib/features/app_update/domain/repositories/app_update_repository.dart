import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart' show CancelToken;

import '/core/errors/failures.dart';
import '../entities/app_update_info.dart';

/// Update check + APK download. The download is a binary stream (not the JSON
/// `ApiClient`), so it lives behind this repository rather than the shared client.
abstract class AppUpdateRepository {
  /// Asks the server whether the running build ([currentVersionCode] +
  /// [versionName]) is behind the latest published build.
  Future<Either<Failure, AppUpdateInfo>> check(int currentVersionCode, String versionName);

  /// Downloads the APK at [url] to local storage (named after [versionCode]),
  /// reporting progress, and resolves to the saved file path. Cancellable.
  Future<Either<Failure, String>> downloadApk(
    String url,
    int versionCode, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  });
}
