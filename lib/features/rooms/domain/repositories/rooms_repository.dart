import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart' show CancelToken;

import '/core/errors/failures.dart';
import '../entities/create_room_params.dart';
import '../entities/download_progress.dart';
import '../entities/room.dart';

abstract class RoomsRepository {
  Future<Either<Failure, List<Room>>> getRooms();

  Future<Either<Failure, Room>> getRoom(String slug);

  /// `true` when the password matches (room unlocked), `false` when it does
  /// not. Network/server problems still surface as a [Failure].
  Future<Either<Failure, bool>> unlockRoom(String slug, String password);

  Future<Either<Failure, CreateRoomResult>> createRoom(
    CreateRoomParams params, {
    void Function(int sent, int total)? onUploadProgress,
    CancelToken? cancelToken,
  });

  Future<Either<Failure, DownloadProgress>> downloadProgress(String jobId);

  Future<Either<Failure, Unit>> deleteRoom(String slug, {String? password});

  /// Upload an SRT/VTT subtitle for an external room; returns the stored
  /// filename. The server also broadcasts `subtitle_changed` over the socket.
  Future<Either<Failure, String>> uploadSubtitle(String slug, String filePath);

  /// Upload a chat voice clip; returns the stored filename.
  Future<Either<Failure, String>> uploadVoice(String slug, String filePath);
}
