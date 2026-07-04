import '/core/errors/exceptions.dart';
import '../../domain/entities/topcinema_series.dart';
import '../../domain/entities/topcinema_source.dart';
import '../topcinema_scraper.dart';

/// The ISOLATED "second way" data source. Discovery + link resolution run
/// ON-DEVICE through [TopcinemaScraper] (the deployed server's IP is blocked by
/// topcinema; the phone's network reaches it). The resolved link is then handed
/// to the existing Create Room screen — so this feature never touches the rooms
/// feature's code, only its UI route.
abstract class TopcinemaRemoteDataSource {
  /// Opens a series by editable [name] (its url slug), or loads a specific
  /// season page by [url] (when switching seasons). [host] pins the mirror the
  /// viewer picked (only used with [name]; a [url] already carries its host).
  Future<TopcinemaSeries> series({String? name, String? url, String? host});

  /// Resolves a parsed episode page to its downloadable qualities.
  Future<List<TopcinemaSource>> resolveEpisode(String episodeUrl);

  /// Resolves a movie (by editable name slug) to its downloadable qualities.
  /// [host] pins the mirror the viewer picked.
  Future<List<TopcinemaSource>> resolveMovie(String title, {String? host});
}

class TopcinemaRemoteDataSourceImpl implements TopcinemaRemoteDataSource {
  TopcinemaRemoteDataSourceImpl(this._scraper);

  final TopcinemaScraper _scraper;

  @override
  Future<TopcinemaSeries> series({String? name, String? url, String? host}) {
    if (url != null && url.isNotEmpty) return _scraper.seasonPage(url);
    if (name != null && name.isNotEmpty) return _scraper.seriesByName(name, host: host);
    throw const ServerException('topcinema_not_found');
  }

  @override
  Future<List<TopcinemaSource>> resolveEpisode(String episodeUrl) =>
      _scraper.resolveEpisode(episodeUrl);

  @override
  Future<List<TopcinemaSource>> resolveMovie(String title, {String? host}) =>
      _scraper.resolveMovie(title, host: host);
}
