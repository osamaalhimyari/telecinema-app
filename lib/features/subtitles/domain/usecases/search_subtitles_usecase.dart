import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '/core/UseCase/usecase.dart';
import '/core/errors/failures.dart';
import '../entities/subtitle_result.dart';
import '../repositories/subtitles_repository.dart';

class SearchSubtitlesParams extends Equatable {
  const SearchSubtitlesParams({
    this.imdbId,
    this.season,
    this.episode,
    required this.langId,
  });

  final String? imdbId;
  final int? season;
  final int? episode;
  final String langId;

  @override
  List<Object?> get props => [imdbId, season, episode, langId];
}

/// Finds subtitles for a title in a chosen language. An empty list means
/// "searched, nothing available".
class SearchSubtitlesUseCase implements UseCase<List<SubtitleResult>, SearchSubtitlesParams> {
  SearchSubtitlesUseCase(this._repository);
  final SubtitlesRepository _repository;

  @override
  Future<Either<Failure, List<SubtitleResult>>> call(SearchSubtitlesParams params) =>
      _repository.search(
        imdbId: params.imdbId,
        season: params.season,
        episode: params.episode,
        langId: params.langId,
      );
}
