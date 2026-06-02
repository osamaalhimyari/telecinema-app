import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../repositories/rooms_repository.dart';

class UnlockRoomParams extends Equatable {
  const UnlockRoomParams({required this.slug, required this.password});
  final String slug;
  final String password;

  @override
  List<Object?> get props => [slug, password];
}

/// Returns `true` when the password unlocks the room, `false` when it is wrong.
class UnlockRoomUseCase implements UseCase<bool, UnlockRoomParams> {
  UnlockRoomUseCase(this._repository);
  final RoomsRepository _repository;

  @override
  Future<Either<Failure, bool>> call(UnlockRoomParams params) =>
      _repository.unlockRoom(params.slug, params.password);
}
