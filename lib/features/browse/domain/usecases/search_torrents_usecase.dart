import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../entities/torrent_option.dart';
import '../repositories/browse_repository.dart';

class SearchTorrentsParams extends Equatable {
  const SearchTorrentsParams({required this.query});
  final String query;

  @override
  List<Object?> get props => [query];
}

/// Free-text torrent search, used to resolve a single episode (`Show SxxExx`)
/// that the IMDB-id search only returned inside a season pack.
class SearchTorrentsUseCase implements UseCase<List<TorrentOption>, SearchTorrentsParams> {
  SearchTorrentsUseCase(this._repository);
  final BrowseRepository _repository;

  @override
  Future<Either<Failure, List<TorrentOption>>> call(SearchTorrentsParams params) =>
      _repository.searchTorrents(query: params.query);
}
