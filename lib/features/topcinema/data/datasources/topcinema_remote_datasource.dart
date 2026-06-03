import '/core/errors/exceptions.dart';
import '/core/network/api_client.dart';
import '../../domain/entities/topcinema_series.dart';
import '../../domain/entities/topcinema_source.dart';
import '../topcinema_scraper.dart';

/// Progress of a topcinema download room being created. Mirrors the shape of
/// the existing `GET /api/rooms/download/:jobId` poll.
class TopcinemaDownload {
  const TopcinemaDownload({required this.status, this.percent, this.slug, this.error});

  final String status; // 'pending' | 'downloading' | 'done' | 'error'
  final int? percent;
  final String? slug;
  final String? error;

  bool get isDone => status == 'done';
  bool get isError => status == 'error';
}

/// The ISOLATED "second way" data source. Discovery + link resolution run
/// ON-DEVICE through [TopcinemaScraper] (the deployed server's IP is blocked by
/// topcinema; the phone's network reaches it). Only the final `download` room
/// creation reuses the existing public `/api/rooms` endpoints via [ApiClient],
/// so it never imports or modifies the rooms feature.
abstract class TopcinemaRemoteDataSource {
  /// Opens a series by editable [name] (its url slug), or loads a specific
  /// season page by [url] (when switching seasons).
  Future<TopcinemaSeries> series({String? name, String? url});

  /// Resolves a parsed episode page to its downloadable qualities.
  Future<List<TopcinemaSource>> resolveEpisode(String episodeUrl);

  /// Resolves a movie (by editable name slug) to its downloadable qualities.
  Future<List<TopcinemaSource>> resolveMovie(String title);

  /// Creates a `download` room that fetches [videoUrl] server-side. Returns the
  /// poll job id.
  Future<String> createDownloadRoom({
    required String name,
    required String videoUrl,
    String? category,
    String? imdbId,
  });

  Future<TopcinemaDownload> downloadProgress(String jobId);
}

class TopcinemaRemoteDataSourceImpl implements TopcinemaRemoteDataSource {
  TopcinemaRemoteDataSourceImpl(this._client, this._scraper);

  final ApiClient _client;
  final TopcinemaScraper _scraper;

  @override
  Future<TopcinemaSeries> series({String? name, String? url}) {
    if (url != null && url.isNotEmpty) return _scraper.seasonPage(url);
    if (name != null && name.isNotEmpty) return _scraper.seriesByName(name);
    throw const ServerException('topcinema_not_found');
  }

  @override
  Future<List<TopcinemaSource>> resolveEpisode(String episodeUrl) =>
      _scraper.resolveEpisode(episodeUrl);

  @override
  Future<List<TopcinemaSource>> resolveMovie(String title) => _scraper.resolveMovie(title);

  @override
  Future<String> createDownloadRoom({
    required String name,
    required String videoUrl,
    String? category,
    String? imdbId,
  }) async {
    final res = await _client.post(
      '/rooms',
      data: {
        'name': name,
        'roomType': 'download',
        'videoUrl': videoUrl,
        'category': ?category,
        'imdbId': ?imdbId,
      },
    );
    if (!res.success) {
      throw ServerException(res.message ?? 'error_request_failed');
    }
    final data = res.data;
    final jobId = data is Map<String, dynamic> ? data['jobId']?.toString() : null;
    if (jobId == null || jobId.isEmpty) {
      throw const ServerException('error_request_failed');
    }
    return jobId;
  }

  @override
  Future<TopcinemaDownload> downloadProgress(String jobId) async {
    final res = await _client.get('/rooms/download/$jobId');
    if (!res.success) {
      throw ServerException(res.message ?? 'error_request_failed');
    }
    final data = res.data is Map<String, dynamic>
        ? res.data as Map<String, dynamic>
        : const <String, dynamic>{};
    final pct = data['percent'];
    return TopcinemaDownload(
      status: data['status']?.toString() ?? 'pending',
      percent: pct is num ? pct.toInt() : int.tryParse('${pct ?? ''}'),
      slug: data['slug']?.toString(),
      error: data['error']?.toString(),
    );
  }
}
