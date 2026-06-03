import '/core/errors/exceptions.dart';
import '/core/network/api_client.dart';
import '../../../browse/domain/entities/catalog_item.dart';

/// Talks to the backend's account-less favorites API (`/api/favorites`) — a
/// single global list of saved movies/series. Unlike the Browse catalogue
/// (public Cinemeta over `package:http`), this goes through the app's
/// [ApiClient] and the `{ success, data }` envelope.
///
/// Throws [ServerException] with a stable error key on failure.
abstract class FavoritesRemoteDataSource {
  Future<List<CatalogItem>> list();
  Future<void> add(CatalogItem item);
  Future<void> remove(String mediaId);
}

class FavoritesRemoteDataSourceImpl implements FavoritesRemoteDataSource {
  FavoritesRemoteDataSourceImpl(this._client);

  final ApiClient _client;

  @override
  Future<List<CatalogItem>> list() async {
    final res = await _client.get('/favorites');
    if (!res.success) {
      throw ServerException(res.message ?? 'error_request_failed');
    }
    final data = res.data;
    final raw = data is Map<String, dynamic> ? data['favorites'] : data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((row) {
          final media = row['media'];
          return media is Map
              ? CatalogItem.fromJson(Map<String, dynamic>.from(media))
              : null;
        })
        .whereType<CatalogItem>()
        .where((i) => i.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> add(CatalogItem item) async {
    final res = await _client.post(
      '/favorites',
      data: {
        'mediaId': item.id,
        'mediaType': item.type,
        'media': item.toJson(),
      },
    );
    if (!res.success) {
      throw ServerException(res.message ?? 'error_request_failed');
    }
  }

  @override
  Future<void> remove(String mediaId) async {
    final res = await _client.delete('/favorites/$mediaId');
    if (!res.success) {
      throw ServerException(res.message ?? 'error_request_failed');
    }
  }
}
