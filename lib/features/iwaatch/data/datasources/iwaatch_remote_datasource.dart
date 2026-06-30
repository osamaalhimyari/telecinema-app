import '/core/errors/exceptions.dart';
import '/core/network/api_client.dart';
import '../../domain/entities/iwaatch_source.dart';

/// The ISOLATED "iwaatch direct link" data source. Unlike the on-device
/// topcinema scraper, iwaatch.com is geo/DNS-blocked for the client but
/// reachable from the server — so resolution runs on the BACKEND and this just
/// calls `GET /api/iwaatch/resolve` through the app's [ApiClient] (`{ success,
/// data }` envelope). The resolved link is handed to the existing Create Room
/// screen.
///
/// Throws [ServerException] with a stable key (`iwaatch_not_found` /
/// `iwaatch_unavailable`) so the UI can translate it.
abstract class IwaatchRemoteDataSource {
  /// Resolves a movie (by editable name/slug) to its direct sources.
  Future<List<IwaatchSource>> resolveMovie(String title);
}

class IwaatchRemoteDataSourceImpl implements IwaatchRemoteDataSource {
  IwaatchRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<IwaatchSource>> resolveMovie(String title) async {
    final res = await _client.get('/iwaatch/resolve', queryParameters: {'title': title});
    if (!res.success) {
      throw ServerException(res.message ?? 'iwaatch_unavailable');
    }
    final data = res.data;
    final raw = data is Map ? data['sources'] : null;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => IwaatchSource.fromJson(Map<String, dynamic>.from(m)))
        .where((s) => s.url.isNotEmpty)
        .toList(growable: false);
  }
}
