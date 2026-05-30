import 'package:dartz/dartz.dart';

import '/core/errors/exceptions.dart';
import '/core/errors/failures.dart';
import '/core/localization/translation_keys.dart';
import '../../domain/entities/catalog_item.dart';
import '../../domain/entities/meta_detail.dart';
import '../../domain/entities/torrent_option.dart';
import '../../domain/repositories/browse_repository.dart';
import '../datasources/cinemeta_datasource.dart';
import '../datasources/torrent_datasource.dart';

/// Turns datasource [ServerException]s into [Failure]s whose `message` is a
/// [TranslationKeys] constant — mirrors `RoomsRepositoryImpl`.
class BrowseRepositoryImpl implements BrowseRepository {
  BrowseRepositoryImpl(this._cinemeta, this._torrents);

  final CinemetaDataSource _cinemeta;
  final TorrentDataSource _torrents;

  @override
  Future<Either<Failure, List<CatalogItem>>> catalog({
    required String type,
    int skip = 0,
  }) => _guard(() => _cinemeta.catalog(type: type, skip: skip));

  @override
  Future<Either<Failure, List<CatalogItem>>> search({
    required String type,
    required String query,
  }) => _guard(() => _cinemeta.search(type: type, query: query));

  @override
  Future<Either<Failure, MetaDetail>> detail({
    required String type,
    required String id,
  }) => _guard(() => _cinemeta.detail(type: type, id: id));

  @override
  Future<Either<Failure, TorrentOption?>> findTorrent({
    required String imdbId,
    required String title,
  }) => _guard(() => _torrents.findBest(imdbId: imdbId, title: title));

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ServerException catch (e) {
      if (e.statusCode == 404) {
        return const Left(NotFoundFailure(TranslationKeys.errorNotFound));
      }
      // `message` is already a stable transport key (error_timeout, …).
      return Left(ServerFailure(e.message));
    } catch (_) {
      return const Left(UnknownFailure(TranslationKeys.errorUnknown));
    }
  }
}
