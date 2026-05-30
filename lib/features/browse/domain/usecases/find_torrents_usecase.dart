import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../entities/torrent_option.dart';
import '../repositories/browse_repository.dart';

class FindTorrentsParams extends Equatable {
  const FindTorrentsParams({required this.imdbId, required this.title});
  final String imdbId;
  final String title;

  @override
  List<Object?> get props => [imdbId, title];
}

/// Resolves every available torrent for a title, most-seeded first. An empty
/// list means "searched, but nothing available" — the detail page then shows
/// "Not available currently". The picker groups the list into episodes (series)
/// or qualities (movies).
class FindTorrentsUseCase implements UseCase<List<TorrentOption>, FindTorrentsParams> {
  FindTorrentsUseCase(this._repository);
  final BrowseRepository _repository;

  @override
  Future<Either<Failure, List<TorrentOption>>> call(FindTorrentsParams params) =>
      _repository.findTorrents(imdbId: params.imdbId, title: params.title);
}
