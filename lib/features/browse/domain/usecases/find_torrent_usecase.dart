import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../entities/torrent_option.dart';
import '../repositories/browse_repository.dart';

class FindTorrentParams extends Equatable {
  const FindTorrentParams({required this.imdbId, required this.title});
  final String imdbId;
  final String title;

  @override
  List<Object?> get props => [imdbId, title];
}

/// Resolves the best torrent for a title. A `null` payload means "searched, but
/// nothing available" — the detail page shows "Not available currently".
class FindTorrentUseCase implements UseCase<TorrentOption?, FindTorrentParams> {
  FindTorrentUseCase(this._repository);
  final BrowseRepository _repository;

  @override
  Future<Either<Failure, TorrentOption?>> call(FindTorrentParams params) =>
      _repository.findTorrent(imdbId: params.imdbId, title: params.title);
}
