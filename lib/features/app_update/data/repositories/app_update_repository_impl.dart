import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart' show CancelToken;

import '/core/errors/exceptions.dart';
import '/core/errors/failures.dart';
import '/core/localization/translation_keys.dart';
import '../../domain/entities/app_update_info.dart';
import '../../domain/repositories/app_update_repository.dart';
import '../datasources/app_update_remote_datasource.dart';

/// Translates data-source exceptions into [Failure]s whose `message` is a
/// [TranslationKeys] entry the UI can localize. Mirrors `RoomsRepositoryImpl`.
class AppUpdateRepositoryImpl implements AppUpdateRepository {
  AppUpdateRepositoryImpl(this._remote);

  final AppUpdateRemoteDataSource _remote;

  @override
  Future<Either<Failure, AppUpdateInfo>> check(int currentVersionCode, String versionName) =>
      _guard(() => _remote.check(currentVersionCode, versionName));

  @override
  Future<Either<Failure, String>> downloadApk(
    String url,
    int versionCode, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) => _guard(
    () => _remote.downloadApk(
      url,
      versionCode,
      onProgress: onProgress,
      cancelToken: cancelToken,
    ),
  );

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      return Left(_map(e));
    } catch (_) {
      return const Left(UnknownFailure(TranslationKeys.errorUnknown));
    }
  }

  Failure _map(ServerException e) {
    switch (e.message) {
      case 'operation_canceled':
        return const ServerFailure(TranslationKeys.operationCanceled);
      case 'download_failed':
        return const ServerFailure(TranslationKeys.updateError);
    }
    if (e.statusCode == 404) return const NotFoundFailure(TranslationKeys.errorNotFound);
    // Otherwise `message` is already a stable transport key (error_timeout…).
    return ServerFailure(e.message);
  }
}
