import '/core/errors/exceptions.dart';
import '/core/network/api_client.dart';
import '../domain/entities/server_operation.dart';

/// Reads + cancels this device's server transfers over the JSON API. The device
/// id travels in the `X-Device-Id` header (added by [DioApiClient]); the server
/// uses it to scope `/api/operations` to the operations *this* device started.
class OperationsDataSource {
  OperationsDataSource(this._client);

  final ApiClient _client;

  /// This device's in-flight + recently-finished server operations, newest
  /// first. Empty when there are none.
  Future<List<ServerOperation>> list() async {
    final res = await _client.get('/operations');
    if (!res.success) throw ServerException(res.message ?? 'error_request_failed');
    final data = res.data;
    final raw = data is Map<String, dynamic> ? data['operations'] : data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => ServerOperation.fromJson(Map<String, dynamic>.from(m)))
        .toList(growable: false);
  }

  /// Cancels a running server operation by its job id.
  Future<void> cancel(String id) async {
    final res = await _client.post('/rooms/download/$id/cancel');
    if (!res.success) throw ServerException(res.message ?? 'error_request_failed');
  }
}
