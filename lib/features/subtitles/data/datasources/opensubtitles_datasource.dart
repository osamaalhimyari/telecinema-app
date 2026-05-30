import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '/core/errors/exceptions.dart';
import '/features/browse/data/json_parse.dart';
import '../../domain/entities/subtitle_result.dart';

/// Talks to the OpenSubtitles **legacy REST API** (`rest.opensubtitles.org`) —
/// a keyless public endpoint that searches by IMDB id or free-text query and
/// returns a JSON array of candidates. Like the Browse datasources, this goes
/// over `package:http` directly rather than the app backend.
///
/// Throws [ServerException] with a stable error key on transport failure.
abstract class OpenSubtitlesDataSource {
  /// Subtitles for [imdbId] (preferred) or a free-text [query], in [langId]
  /// (ISO 639-2, e.g. `ara`). Most-downloaded first. Empty when none match.
  Future<List<SubtitleResult>> search({
    String? imdbId,
    String? query,
    required String langId,
  });

  /// Downloads + ungzips [result] into a temp `.srt` and returns its local
  /// path, ready to hand to the room's subtitle upload.
  Future<String> download(SubtitleResult result);
}

class OpenSubtitlesDataSourceImpl implements OpenSubtitlesDataSource {
  OpenSubtitlesDataSourceImpl([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 20);

  /// The legacy REST API gates requests on a User-Agent. If results stop
  /// arriving, this is the first thing to swap for a registered UA.
  static const Map<String, String> _headers = {
    'User-Agent': 'TemporaryUserAgent',
    'X-User-Agent': 'TemporaryUserAgent',
  };

  @override
  Future<List<SubtitleResult>> search({
    String? imdbId,
    String? query,
    required String langId,
  }) async {
    final url = buildOpenSubtitlesSearchUrl(imdbId: imdbId, query: query, langId: langId);
    if (url == null) return const []; // nothing to search on
    try {
      final res = await _client.get(Uri.parse(url), headers: _headers).timeout(_timeout);
      if (res.statusCode != 200) {
        throw ServerException('error_request_failed', statusCode: res.statusCode);
      }
      // Empty bodies / non-array payloads mean "no results", not an error.
      final body = res.body.trim();
      if (body.isEmpty) return const [];
      return parseSubtitleResults(jsonDecode(body));
    } on ServerException {
      rethrow;
    } on TimeoutException {
      throw const ServerException('error_timeout');
    } on FormatException {
      return const []; // unexpected payload — treat as no results
    } catch (e) {
      throw ServerException('error_unknown', cause: e);
    }
  }

  @override
  Future<String> download(SubtitleResult result) async {
    try {
      final res = await _client
          .get(Uri.parse(result.downloadLink), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode != 200) {
        throw ServerException('error_request_failed', statusCode: res.statusCode);
      }

      // The download link serves a gzipped subtitle; ungzip it. If the bytes
      // are already plain text (some mirrors don't gzip), fall back to raw.
      List<int> bytes;
      try {
        bytes = gzip.decode(res.bodyBytes);
      } catch (_) {
        bytes = res.bodyBytes;
      }

      final format = result.format.isNotEmpty ? result.format : 'srt';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/sub_${result.id}.$format');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } on ServerException {
      rethrow;
    } on TimeoutException {
      throw const ServerException('error_timeout');
    } catch (e) {
      throw ServerException('error_unknown', cause: e);
    }
  }
}

// ===========================================================================
// Pure helpers (unit-tested without the network)
// ===========================================================================

const String kOpenSubtitlesBase = 'https://rest.opensubtitles.org';

/// The numeric part of an IMDB id, with the `tt` prefix and leading zeros
/// stripped (`tt1190634` → `1190634`, `tt0133093` → `133093`). Empty when there
/// are no digits.
String imdbDigits(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  return int.parse(digits).toString();
}

/// Builds the legacy search URL. Prefers `imdbid-…` when a usable IMDB id is
/// given, otherwise `query-…` from the title. Returns null when neither yields
/// a key to search on.
String? buildOpenSubtitlesSearchUrl({
  String? imdbId,
  String? query,
  required String langId,
}) {
  final digits = imdbId == null ? '' : imdbDigits(imdbId);
  final String segment;
  if (digits.isNotEmpty) {
    segment = 'imdbid-$digits';
  } else {
    final q = (query ?? '').trim();
    if (q.isEmpty) return null;
    segment = 'query-${Uri.encodeComponent(q)}';
  }
  return '$kOpenSubtitlesBase/search/$segment/sublanguageid-$langId';
}

/// Maps the OpenSubtitles JSON array into [SubtitleResult]s: keeps only rows
/// with a download link, de-duplicates by file id, and sorts most-downloaded
/// first.
List<SubtitleResult> parseSubtitleResults(dynamic json) {
  if (json is! List) return const [];

  final seen = <String>{};
  final out = <SubtitleResult>[];
  for (final raw in json.whereType<Map>()) {
    final m = Map<String, dynamic>.from(raw);
    final link = asString(m['SubDownloadLink']);
    final id = asString(m['IDSubtitleFile']) ?? asString(m['IDSubtitle']);
    if (link == null || id == null || !seen.add(id)) continue;

    out.add(
      SubtitleResult(
        id: id,
        fileName: asString(m['SubFileName']) ?? id,
        langId: asString(m['SubLanguageID']) ?? '',
        langName: asString(m['LanguageName']) ?? '',
        format: (asString(m['SubFormat']) ?? 'srt').toLowerCase(),
        downloadLink: link,
        releaseName: asString(m['MovieReleaseName']) ?? '',
        downloadsCount: asInt(m['SubDownloadsCnt']),
        rating: double.tryParse(asString(m['SubRating']) ?? '') ?? 0,
      ),
    );
  }

  out.sort((a, b) => b.downloadsCount.compareTo(a.downloadsCount));
  return out;
}
