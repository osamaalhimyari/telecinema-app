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
    String? query,
    required String langId,
  }) => _guard(() => _datasource.search(imdbId: imdbId, query: query, langId: langId));

  @override
  Future<Either<Failure, String>> download(SubtitleResult result) =>
      _guard(() => _datasource.download(result));

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      if (e.statusCode == 404) {
        return const Left(NotFoundFailure(TranslationKeys.errorNotFound));
      }
      return Left(ServerFailure(e.message));
    } catch (_) {
      return const Left(UnknownFailure(TranslationKeys.errorUnknown));
    }
  }
}
