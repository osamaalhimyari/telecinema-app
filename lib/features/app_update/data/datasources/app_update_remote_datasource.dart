import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '/core/errors/exceptions.dart';
import '/core/network/api_client.dart';
import '../../domain/entities/app_update_info.dart';
import '../models/app_update_info_model.dart';

abstract class AppUpdateRemoteDataSource {
  Future<AppUpdateInfo> check(int currentVersionCode, String versionName);

  Future<String> downloadApk(
    String url,
    int versionCode, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  });
}

class AppUpdateRemoteDataSourceImpl implements AppUpdateRemoteDataSource {
  AppUpdateRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  /// A bare Dio for the binary APK download — separate from the JSON [ApiClient]
  /// (different content type, progress stream, and an absolute URL).
  final Dio _downloadDio = Dio();

  @override
  Future<AppUpdateInfo> check(int currentVersionCode, String versionName) async {
    final res = await _client.get(
      '/app/version',
      queryParameters: {
        'versionCode': currentVersionCode,
        'versionName': versionName,
        'platform': 'android',
      },
    );
    if (!res.success) {
      throw ServerException(res.message ?? 'error_unknown', statusCode: res.statusCode);
    }
    final data = res.data is Map<String, dynamic>
        ? res.data as Map<String, dynamic>
        : <String, dynamic>{};
    return AppUpdateInfoModel.fromJson(data);
  }

  @override
  Future<String> downloadApk(
    String url,
    int versionCode, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    // App-specific external dir needs no storage permission and is readable by
    // the package installer (via open_filex's bundled FileProvider).
    final dir = await getExternalStorageDirectory() ?? await getApplicationSupportDirectory();
    final path = '${dir.path}/update-$versionCode.apk';

    try {
      await _downloadDio.download(
        url,
        path,
        onReceiveProgress: onProgress,
        cancelToken: cancelToken,
        deleteOnError: true,
      );
      return path;
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) throw const ServerException('operation_canceled');
      throw ServerException('download_failed', cause: e);
    }
  }
}
