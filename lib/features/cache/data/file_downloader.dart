import 'dart:io';

import 'package:dio/dio.dart';

/// Streams an HTTP(S) resource to [savePath] with resume support.
///
/// Resume is driven by [startOffset]: when it is > 0 a `Range: bytes=<offset>-`
/// header is sent and, if the server honours it (`206 Partial Content`), the new
/// bytes are appended to the existing partial file. If the server ignores the
/// range and replies `200`, the download restarts from the beginning (the file
/// is truncated), so a non-ranged server can never corrupt the result.
///
/// Cancelling via [cancelToken] stops the stream and leaves the partial file on
/// disk untouched — the next call resumes from there.
class FileDownloader {
  FileDownloader([Dio? dio]) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<void> download({
    required String url,
    required String savePath,
    int startOffset = 0,
    CancelToken? cancelToken,
    void Function(int received, int? total)? onProgress,
  }) async {
    final response = await _dio.get<ResponseBody>(
      url,
      cancelToken: cancelToken,
      options: Options(
        responseType: ResponseType.stream,
        followRedirects: true,
        // A healthy but slow transfer of a multi-GB file must not time out.
        receiveTimeout: Duration.zero,
        headers: startOffset > 0 ? {'range': 'bytes=$startOffset-'} : null,
        validateStatus: (s) => s != null && s >= 200 && s < 400,
      ),
    );

    final partial = response.statusCode == 206;
    final start = partial ? startOffset : 0;
    final total = _totalBytes(response.headers, partial: partial);

    final file = File(savePath);
    await file.parent.create(recursive: true);
    // Append onto the partial only when the server actually resumed; otherwise
    // overwrite from byte 0.
    final raf = await file.open(mode: partial ? FileMode.append : FileMode.write);

    var received = start;
    onProgress?.call(received, total);
    try {
      await for (final chunk in response.data!.stream) {
        await raf.writeFrom(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
    } finally {
      await raf.close();
    }
  }

  /// Full size of the resource. From `Content-Range` (`bytes a-b/total`) when
  /// present. On a non-partial (200) response `Content-Length` is the whole
  /// file. On a partial (206) response `Content-Length` is only the *range*
  /// length, not the total — so without a `Content-Range` we report null
  /// (indeterminate) rather than a wrong total that would never complete.
  int? _totalBytes(Headers headers, {required bool partial}) {
    final range = headers.value('content-range');
    if (range != null) {
      final slash = range.lastIndexOf('/');
      if (slash != -1) {
        final t = int.tryParse(range.substring(slash + 1).trim());
        if (t != null && t > 0) return t;
      }
    }
    if (partial) return null;
    final len = headers.value('content-length');
    final l = len != null ? int.tryParse(len) : null;
    return (l != null && l > 0) ? l : null;
  }
}
