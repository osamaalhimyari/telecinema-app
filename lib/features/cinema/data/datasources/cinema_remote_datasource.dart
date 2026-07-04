import '../../domain/entities/cinema_detail.dart';
import '../../domain/entities/cinema_item.dart';
import '../../domain/entities/cinema_season.dart';
import '../../domain/entities/cinema_server.dart';
import '../../domain/entities/cinema_stream.dart';
import '../cinema_api.dart';
import '../cinema_resolver.dart';

/// The single data entry point for the isolated Cinema feature. Browsing and
/// search go through [CinemaApi]; turning a chosen server into a downloadable
/// link goes through the on-device [CinemaResolver]. Mirrors topcinema's
/// datasource so the feature reads the same as its siblings.
///
/// Surfaces [ServerException]s (stable, translatable keys) from both layers.
abstract class CinemaRemoteDataSource {
  Future<({List<CinemaItem> items, bool hasMore})> catalog({
    required String listing,
    int page,
  });
  Future<List<CinemaItem>> search(String query);
  Future<CinemaDetail> detail({required int id, required bool isSeries});
  Future<List<CinemaEpisode>> season(int seasonId);
  Future<List<CinemaStream>> resolve(CinemaServer server);
}

class CinemaRemoteDataSourceImpl implements CinemaRemoteDataSource {
  CinemaRemoteDataSourceImpl(this._api, this._resolver);

  final CinemaApi _api;
  final CinemaResolver _resolver;

  @override
  Future<({List<CinemaItem> items, bool hasMore})> catalog({
    required String listing,
    int page = 1,
  }) =>
      _api.catalog(listing: listing, page: page);

  @override
  Future<List<CinemaItem>> search(String query) => _api.search(query);

  @override
  Future<CinemaDetail> detail({required int id, required bool isSeries}) =>
      isSeries ? _api.seriesDetail(id) : _api.movieDetail(id);

  @override
  Future<List<CinemaEpisode>> season(int seasonId) => _api.season(seasonId);

  @override
  Future<List<CinemaStream>> resolve(CinemaServer server) =>
      _resolver.resolve(server);
}
