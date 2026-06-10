import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '/core/config/app_config.dart';
import '/core/device/device_identity.dart';
import '../errors/exceptions.dart';
import 'api_client.dart';
import 'api_response.dart';

/// Dio-backed [ApiClient]. There is no auth token in the watch-party app —
/// rooms are public and password gating is verified per-request — so unlike
/// the rider reference there is no auth interceptor here, just error mapping.
class DioApiClient implements ApiClient {
  final Dio _dio;

  DioApiClient({Dio? dio}) : _dio = dio ?? _buildDio() {
    _dio.interceptors.add(_deviceIdInterceptor());
    if (kDebugMode) _dio.interceptors.add(_loggingInterceptor());
  }

  /// Stamps every request with the stable per-install device id, so the server
  /// can tie long-running operations (downloads/torrents) to this device and
  /// the app can list/cancel them across socket reconnects.
  Interceptor _deviceIdInterceptor() => InterceptorsWrapper(
    onRequest: (o, h) {
      final id = DeviceIdHolder.current;
      if (id != null) o.headers['X-Device-Id'] = id;
      h.next(o);
    },
  );

  static Dio _buildDio() => Dio(
    BaseOptions(
      baseUrl: AppConfig.baseApiUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
    ),
  );

  Interceptor _loggingInterceptor() => InterceptorsWrapper(
    onRequest: (o, h) {
      debugPrint('🚀 ${o.method} ${o.uri}');
      if (o.data != null && o.data is! FormData) debugPrint('📤 ${o.data}');
      h.next(o);
    },
    onResponse: (r, h) {
      debugPrint('✅ ${r.statusCode} ${r.requestOptions.uri}');
      h.next(r);
    },
    onError: (e, h) {
      debugPrint('❌ ${e.type} ${e.requestOptions.uri} | ${e.message}');
      h.next(e);
    },
  );

  // ---- Public API --------------------------------------------------------

  @override
  Future<ApiResponse> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _send(() => _dio.get(path, queryParameters: queryParameters));

  @override
  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) => _send(() => _dio.post(path, data: data, queryParameters: queryParameters));

  @override
  Future<ApiResponse> put(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) => _send(() => _dio.put(path, data: data, queryParameters: queryParameters));

  @override
  Future<ApiResponse> delete(
    String path, {
    Map<String, dynamic>? data,
    Map<String, dynamic>? queryParameters,
  }) => _send(() => _dio.delete(path, data: data, queryParameters: queryParameters));

  @override
  Future<ApiResponse> postMultipart(
    String path, {
    required FormData data,
    Map<String, dynamic>? queryParameters,
    void Function(int sent, int total)? onSendProgress,
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.post(
      path,
      data: data,
      queryParameters: queryParameters,
      onSendProgress: onSendProgress,
      cancelToken: cancelToken,
    ),
  );

  // ---- Core --------------------------------------------------------------

  Future<ApiResponse> _send(Future<Response<dynamic>> Function() call) async {
    try {
      final r = await call();
      final body = (r.data is Map<String, dynamic>)
          ? r.data as Map<String, dynamic>
          : <String, dynamic>{};

      return ApiResponse(
        success: body['success'] == true,
        message: body['message']?.toString(),
        data: body['data'] ?? body,
        statusCode: r.statusCode ?? 0,
      );
    } on DioException catch (e) {
      throw _mapDioError(e);
    } catch (e) {
      throw ServerException('error_unknown', cause: e);
    }
  }

  ServerException _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.cancel:
        return const ServerException('operation_canceled');
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ServerException('error_timeout');
      case DioExceptionType.connectionError:
        return const ServerException('error_no_internet');
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        final body = e.response?.data;
        final serverMsg = (body is Map<String, dynamic>) ? body['message']?.toString() : null;
        if (code == 404) {
          return ServerException('error_not_found', statusCode: code, serverMessage: serverMsg);
        }
        if (code >= 500) {
          return ServerException('error_server', statusCode: code, serverMessage: serverMsg);
        }
        return ServerException(
          'error_request_failed',
          statusCode: code,
          serverMessage: serverMsg,
        );
      default:
        return const ServerException('error_unknown');
    }
  }
}
