import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '/core/config/endpoints.dart';
import '/core/errors/exceptions.dart';
import '/features/browse/data/json_parse.dart';
import '/features/browse/data/torrent_classifier.dart';
import '../../domain/entities/subtitle_result.dart';

/// Talks to the OpenSubtitles **legacy REST API** (`rest.opensubtitles.org`) —
/// a keyless public endpoint that searches by IMDB id or free-text query and
/// returns a JSON array of candidates. Like the Browse datasources, this goes
/// over `package:http` directly rather than the app backend.
///
/// Throws [ServerException] with a stable error key on transport failure.
abstract class OpenSubtitlesDataSource {
  /// Subtitles for [imdbId] (preferred) or a free-text [query], in [langId]
  /// (ISO 639-2, e.g. `ara`). [season]/[episode] narrow a TV search to a single
  /// episode. Most-downloaded first. Empty when none match.
  Future<List<SubtitleResult>> search({
    String? imdbId,
    String? query,
    int? season,
    int? episode,
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
    int? season,
    int? episode,
    required String langId,
  }) async {
    final url = buildOpenSubtitlesSearchUrl(
      imdbId: imdbId,
      query: query,
      season: season,
      episode: episode,
      langId: langId,
    );
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

const String kOpenSubtitlesBase = Endpoints.openSubtitles;

/// The numeric part of an IMDB id, with the `tt` prefix and leading zeros
/// stripped (`tt1190634` → `1190634`, `tt0133093` → `133093`). Empty when there
/// are no digits.
String imdbDigits(String raw) {
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  return int.parse(digits).toString();
}

/// Builds the legacy search URL. Prefers `imdbid-…` when a usable IMDB id is
/// given, otherwise `query-…` from the title. When [season]/[episode] are
/// present they are appended as `season-`/`episode-` segments, which is what
/// narrows a TV search to one episode — an `imdbid-`(series) or `query-`(show)
/// search *without* them returns series-wide noise (or nothing for the specific
/// episode). Returns null when neither a key nor a query is usable.
String? buildOpenSubtitlesSearchUrl({
  String? imdbId,
  String? query,
  int? season,
  int? episode,
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
  final parts = [
    'search',
    segment,
    if (season != null) 'season-$season',
    if (episode != null) 'episode-$episode',
    'sublanguageid-$langId',
  ];
  return '$kOpenSubtitlesBase/${parts.join('/')}';
}

/// Search inputs derived from a torrent/release name (or a plain room title):
/// a clean show/movie title for `query-`, plus any season/episode it carries.
/// Centralises the parsing so the room context and the manual search box agree.
({String query, int? season, int? episode}) subtitleSearchTerms(String release) {
  final se = parseSeasonEpisode(release);
  return (query: showTitleFromRelease(release), season: se.season, episode: se.episode);
}

/// The human-readable name from a magnet URI's `dn` (display name) parameter,
/// URL-decoded (`Breaking+Bad+S01E07…` → `Breaking Bad S01E07…`). Null when the
/// magnet has no `dn` or can't be parsed. Used as a release-name source for
/// subtitle search when no resolved file name is available (e.g. a magnet that
/// was just pasted, before the swarm names the file).
String? magnetDisplayName(String? magnet) {
  if (magnet == null || magnet.trim().isEmpty) return null;
  try {
    final dn = Uri.parse(magnet.trim()).queryParameters['dn']?.trim();
    return (dn == null || dn.isEmpty) ? null : dn;
  } catch (_) {
    return null;
  }
}

/// A clean, searchable show/movie title from a release name:
/// `Breaking.Bad.S01E07.A.Deal.2160p.NF.WEB-DL` → `Breaking Bad`. Cuts at the
/// first `SxxExx` / `Season N` / year / resolution marker — everything past it
/// is release metadata, not the title — then normalises `.`/`_`/`-` to spaces.
/// Returns the whole cleaned string when no marker is present (e.g. a plain
/// room name the user typed).
String showTitleFromRelease(String release) {
  final cut = _titleCutRe.firstMatch(release);
  final head = cut != null ? release.substring(0, cut.start) : release;
  return head.replaceAll(RegExp(r'[._\-]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Marks where a release name stops being the title and starts being metadata:
/// `S01E07`, `Season 1`, a 19xx/20xx year, or a `1080p`-style resolution.
final RegExp _titleCutRe = RegExp(
  r's\d{1,2}[ ._-]?[ex]\d{1,2}'
  r'|season[ ._-]?\d{1,2}'
  r'|\b(?:19|20)\d{2}\b'
  r'|\b\d{3,4}p\b',
  caseSensitive: false,
);

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
