import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../repositories/rooms_repository.dart';

class DeleteRoomParams extends Equatable {
  const DeleteRoomParams({required this.slug, this.password});
  final String slug;
  final String? password;

  @override
  List<Object?> get props => [slug, password];
}

class DeleteRoomUseCase implements UseCase<Unit, DeleteRoomParams> {
  DeleteRoomUseCase(this._repository);
  final RoomsRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(DeleteRoomParams params) =>
      _repository.deleteRoom(params.slug, password: params.password);
}
