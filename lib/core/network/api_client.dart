import 'package:dio/dio.dart';

import 'api_response.dart';

/// Thin abstraction over HTTP. Data sources depend on this interface, not on
/// Dio directly, so the transport can be swapped without touching the
/// domain/data layers.
abstract class ApiClient {
  Future<ApiResponse> get(String path, {Map<String, dynamic>? queryParameters});

  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> put(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  });

  Future<ApiResponse> delete(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  });

  /// Multipart upload (room video / subtitle). [onSendProgress] drives an
  /// upload progress bar; [cancelToken] aborts the request (used by the
  /// operations panel's Cancel).
  Future<ApiResponse> postMultipart(
    String path, {
    required FormData data,
    Map<String, dynamic>? queryParameters,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  });
}
