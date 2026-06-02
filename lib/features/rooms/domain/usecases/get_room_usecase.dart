import 'package:dartz/dartz.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../entities/room.dart';
import '../repositories/rooms_repository.dart';

class GetRoomUseCase implements UseCase<Room, String> {
  GetRoomUseCase(this._repository);
  final RoomsRepository _repository;

  @override
  Future<Either<Failure, Room>> call(String slug) => _repository.getRoom(slug);
}
