import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../entities/catalog_item.dart';
import '../repositories/browse_repository.dart';

class SearchParams extends Equatable {
  const SearchParams({required this.type, required this.query});
  final String type;
  final String query;

  @override
  List<Object?> get props => [type, query];
}

class SearchCatalogUseCase implements UseCase<List<CatalogItem>, SearchParams> {
  SearchCatalogUseCase(this._repository);
  final BrowseRepository _repository;

  @override
  Future<Either<Failure, List<CatalogItem>>> call(SearchParams params) =>
      _repository.search(type: params.type, query: params.query);
}
