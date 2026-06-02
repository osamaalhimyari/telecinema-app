import 'package:dartz/dartz.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../entities/room.dart';
import '../repositories/rooms_repository.dart';

class GetRoomsUseCase implements UseCase<List<Room>, NoParams> {
  GetRoomsUseCase(this._repository);
  final RoomsRepository _repository;

  @override
  Future<Either<Failure, List<Room>>> call(NoParams params) => _repository.getRooms();
}
