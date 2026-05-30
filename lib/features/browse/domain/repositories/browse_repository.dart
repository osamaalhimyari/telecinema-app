import 'package:dartz/dartz.dart';

import '/core/errors/failures.dart';
import '../entities/catalog_item.dart';
import '../entities/meta_detail.dart';
import '../entities/torrent_option.dart';

/// Contract for the Browse catalogue (Cinemeta) and torrent lookup (apibay).
/// Every method returns `Either<Failure, T>`, where a [Failure.message] is a
/// `TranslationKeys` constant — same functional-error contract as the rest of
/// the app.
abstract class BrowseRepository {
  /// A page of the `top` catalogue for [type] (`movie` / `series`), offset by
  /// [skip].
  Future<Either<Failure, List<CatalogItem>>> catalog({
    required String type,
    int skip = 0,
  });

  /// Title search within [type]'s catalogue.
  Future<Either<Failure, List<CatalogItem>>> search({
    required String type,
    required String query,
  });

  /// Full metadata for one title.
  Future<Either<Failure, MetaDetail>> detail({
    required String type,
    required String id,
  });

  /// The best (most-seeded) video torrent for [imdbId], or `null` when the
  /// swarm has nothing — a successful result, not a failure.
  Future<Either<Failure, TorrentOption?>> findTorrent({
    required String imdbId,
    required String title,
  });
}
