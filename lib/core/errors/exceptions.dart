/// Thrown by data sources. The repository layer is the single place these are
/// translated into [Failure]s (see any `*_repository_impl.dart`).
class ServerException implements Exception {
  /// A stable error key (e.g. `error_timeout`) the UI can translate, or a
  /// server-provided message key.
  final String message;
  final int? statusCode;
  final String? serverMessage;
  final Object? cause;

  const ServerException(
    this.message, {
    this.statusCode,
    this.serverMessage,
    this.cause,
  });
}

class CacheException implements Exception {
  final String message;
  const CacheException([this.message = 'cache_error']);
}
