import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart' show CancelToken;

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../entities/create_room_params.dart';
import '../repositories/rooms_repository.dart';

class CreateRoomUseCase implements UseCase<CreateRoomResult, CreateRoomParams> {
  CreateRoomUseCase(this._repository);
  final RoomsRepository _repository;

  void Function(int sent, int total)? onUploadProgress;

  /// Set per-submit so the operations panel can abort an in-flight upload.
  CancelToken? cancelToken;

  @override
  Future<Either<Failure, CreateRoomResult>> call(CreateRoomParams params) =>
      _repository.createRoom(params, onUploadProgress: onUploadProgress, cancelToken: cancelToken);
}
