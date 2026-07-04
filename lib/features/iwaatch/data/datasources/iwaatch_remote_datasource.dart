import '/core/errors/exceptions.dart';
import '/core/network/api_client.dart';
import '../../domain/entities/iwaatch_source.dart';

/// The ISOLATED "iwaatch direct link" source. Unlike topcinema (scraped
/// on-device because the server's IP is blocked there), iwaatch.com is the
/// mirror image: geo/DNS-blocked for the client but reachable from our server,
/// so resolution runs ON THE BACKEND. This datasource just calls
/// `GET /api/iwaatch/resolve?title=<name>` and parses the returned sources.
///
/// Movies only — series are "coming soon" on iwaatch. The resolved link is
/// handed to the existing Create Room screen, so this feature never touches the
/// rooms feature's code, only its UI route.
abstract class IwaatchRemoteDataSource {
  /// Resolves a movie (by editable name/slug) to its direct sources.
  Future<List<IwaatchSource>> resolveMovie(String title);
}

class IwaatchRemoteDataSourceImpl implements IwaatchRemoteDataSource {
  IwaatchRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  @override
  Future<List<IwaatchSource>> resolveMovie(String title) async {
    final List<IwaatchSource> sources;
    try {
      final res = await _api.get(
        '/iwaatch/resolve',
        queryParameters: {'title': title},
      );
      final data = res.data;
      final raw = (data is Map<String, dynamic>) ? data['sources'] : null;
      sources = (raw is List)
          ? raw.whereType<Map<String, dynamic>>().map(IwaatchSource.fromJson).toList()
          : const [];
    } on ServerException catch (e) {
      // Map the transport's generic keys / HTTP status to iwaatch-specific
      // messages so the picker can show a meaningful line. The controller
      // answers 404 with `iwaatch_not_found`, anything else is "unavailable".
      if (e.statusCode == 404 || e.serverMessage == 'iwaatch_not_found') {
        throw const ServerException('iwaatch_not_found');
      }
      throw const ServerException('iwaatch_unavailable');
    }
    if (sources.isEmpty) throw const ServerException('iwaatch_not_found');
    return sources;
  }
}
