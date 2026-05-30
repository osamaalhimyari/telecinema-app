import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../entities/catalog_item.dart';
import '../repositories/browse_repository.dart';

class CatalogParams extends Equatable {
  const CatalogParams({required this.type, this.skip = 0});
  final String type;
  final int skip;

  @override
  List<Object?> get props => [type, skip];
}

class GetCatalogUseCase implements UseCase<List<CatalogItem>, CatalogParams> {
  GetCatalogUseCase(this._repository);
  final BrowseRepository _repository;

  @override
  Future<Either<Failure, List<CatalogItem>>> call(CatalogParams params) =>
      _repository.catalog(type: params.type, skip: params.skip);
}
