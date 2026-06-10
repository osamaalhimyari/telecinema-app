import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart' show CancelToken;

import '/core/errors/exceptions.dart';
import '/core/errors/failures.dart';
import '/core/localization/translation_keys.dart';
import '../../domain/entities/create_room_params.dart';
import '../../domain/entities/download_progress.dart';
import '../../domain/entities/room.dart';
import '../../domain/repositories/rooms_repository.dart';
import '../datasources/rooms_remote_datasource.dart';

/// The one place exceptions become [Failure]s. Each failure's `message` is a
/// valid [TranslationKeys] entry, so the UI can translate it directly.
class RoomsRepositoryImpl implements RoomsRepository {
  RoomsRepositoryImpl(this._remote);

  final RoomsRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<Room>>> getRooms() => _guard(() async {
    final models = await _remote.fetchRooms();
    return models.map((m) => m.toEntity()).toList(growable: false);
  });

  @override
  Future<Either<Failure, Room>> getRoom(String slug) =>
      _guard(() async => (await _remote.fetchRoom(slug)).toEntity());

  @override
  Future<Either<Failure, bool>> unlockRoom(String slug, String password) =>
      _guard(() => _remote.unlock(slug, password));

  @override
  Future<Either<Failure, CreateRoomResult>> createRoom(
    CreateRoomParams params, {
    void Function(int sent, int total)? onUploadProgress,
    CancelToken? cancelToken,
  }) => _guard(() async {
    final result = await _remote.create(
      params,
      onUploadProgress: onUploadProgress,
      cancelToken: cancelToken,
    );
    return CreateRoomResult(room: result.room?.toEntity(), jobId: result.jobId);
  });

  @override
  Future<Either<Failure, DownloadProgress>> downloadProgress(String jobId) =>
      _guard(() => _remote.downloadProgress(jobId));

  @override
  Future<Either<Failure, Unit>> deleteRoom(String slug, {String? password}) => _guard(() async {
    await _remote.delete(slug, password: password);
    return unit;
  });

  @override
  Future<Either<Failure, String>> uploadSubtitle(String slug, String filePath) =>
      _guard(() => _remote.uploadSubtitle(slug, filePath));

  /// Runs [action], translating any thrown exception into a [Failure].
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      return Left(_map(e));
    } catch (e) {
      return Left(UnknownFailure(TranslationKeys.errorUnknown));
    }
  }

  Failure _map(ServerException e) {
    switch (e.serverMessage) {
      case 'incorrect_password':
        return const ServerFailure(TranslationKeys.incorrectPassword);
      case 'room_not_empty':
        return const ServerFailure(TranslationKeys.roomNotEmpty);
      case 'room_not_found':
        return const NotFoundFailure(TranslationKeys.errorNotFound);
    }
    if (e.statusCode == 404) return const NotFoundFailure(TranslationKeys.errorNotFound);
    // Otherwise `message` is already a stable transport key (error_timeout…).
    return ServerFailure(e.message);
  }
}
