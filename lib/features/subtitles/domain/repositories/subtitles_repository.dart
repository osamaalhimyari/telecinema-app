import 'package:dartz/dartz.dart';

import '/core/errors/failures.dart';
import '../entities/subtitle_result.dart';

/// Contract for the OpenSubtitles lookup. Mirrors the Browse repository's
/// functional-error style: every method returns `Either<Failure, T>` where a
/// [Failure.message] is a `TranslationKeys` constant.
abstract class SubtitlesRepository {
  /// Subtitles for [imdbId] (preferred) or a free-text [query] in [langId],
  /// optionally narrowed to a TV [season]/[episode]. An empty list means
  /// "searched, nothing found" — a success, not a failure.
  Future<Either<Failure, List<SubtitleResult>>> search({
    String? imdbId,
    String? query,
    int? season,
    int? episode,
    required String langId,
  });

  /// Downloads + ungzips [result] and returns the local file path.
  Future<Either<Failure, String>> download(SubtitleResult result);
}
