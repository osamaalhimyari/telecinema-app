import 'package:dartz/dartz.dart';

import '/core/errors/exceptions.dart';
import '/core/errors/failures.dart';
import '/core/localization/translation_keys.dart';
import '../../domain/entities/subtitle_result.dart';
import '../../domain/repositories/subtitles_repository.dart';
import '../datasources/opensubtitles_datasource.dart';

/// Turns datasource [ServerException]s into [Failure]s whose `message` is a
/// [TranslationKeys] constant — mirrors `BrowseRepositoryImpl`.
class SubtitlesRepositoryImpl implements SubtitlesRepository {
  SubtitlesRepositoryImpl(this._datasource);

  final OpenSubtitlesDataSource _datasource;

  @override
  Future<Either<Failure, List<SubtitleResult>>> search({
    String? imdbId,
    int? season,
    int? episode,
    required String langId,
  }) => _guard(
    () => _datasource.search(
      imdbId: imdbId,
      season: season,
      episode: episode,
      langId: langId,
    ),
  );

  @override
  Future<Either<Failure, String>> download(SubtitleResult result) =>
      _guard(() => _datasource.download(result));

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      final detail = _detailOf(e);
      if (e.statusCode == 404) {
        return Left(NotFoundFailure(TranslationKeys.errorNotFound, detail: detail));
      }
      return Left(ServerFailure(e.message, detail: detail));
    } catch (e) {
      return Left(UnknownFailure(TranslationKeys.errorUnknown, detail: e.toString()));
    }
  }

  /// A short, human-readable source hint from a [ServerException] — the HTTP
  /// status and/or any server message — shown verbatim so the user can see what
  /// actually failed (e.g. `OpenSubtitles · HTTP 503`).
  String? _detailOf(ServerException e) {
    final parts = <String>[
      if (e.statusCode != null) 'HTTP ${e.statusCode}',
      if (e.serverMessage != null && e.serverMessage!.isNotEmpty) e.serverMessage!,
      if (e.statusCode == null && e.serverMessage == null && e.cause != null) e.cause.toString(),
    ];
    if (parts.isEmpty) return null;
    return 'OpenSubtitles · ${parts.join(' · ')}';
  }
}
