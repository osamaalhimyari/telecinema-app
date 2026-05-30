import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../entities/meta_detail.dart';
import '../repositories/browse_repository.dart';

class DetailParams extends Equatable {
  const DetailParams({required this.type, required this.id});
  final String type;
  final String id;

  @override
  List<Object?> get props => [type, id];
}

class GetMetaDetailUseCase implements UseCase<MetaDetail, DetailParams> {
  GetMetaDetailUseCase(this._repository);
  final BrowseRepository _repository;

  @override
  Future<Either<Failure, MetaDetail>> call(DetailParams params) =>
      _repository.detail(type: params.type, id: params.id);
}
