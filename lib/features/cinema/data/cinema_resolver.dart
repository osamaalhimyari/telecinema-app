import 'dart:async';

import 'package:http/http.dart' as http;

import '/core/errors/exceptions.dart';
import '../domain/entities/cinema_server.dart';
import '../domain/entities/cinema_stream.dart';
import 'packed_js.dart';

/// Turns a [CinemaServer] into direct, downloadable media links — the
/// "parse the server till you find the download video link" step.
///
/// Runs ON-DEVICE (like the topcinema scraper) and is the intentionally fragile
/// part of the feature, kept in one isolated place. Strategy, in order:
///
///  1. **Direct** — the link already ends in `.mp4`/`.m3u8` (the dominant
///     yandex / seriesmp4 servers, which ship one entry per quality). Return as-is.
///  2. **Embed page** — fetch it with the right `Referer`/UA, then pull the media
///     url straight out of the HTML.
///  3. **Packed** — if the page hid the url inside `eval(function(p,a,c,k,e,d…))`,
///     unpack it ([PackedJs]) and pull the url from the expanded source.
///
/// Hosts that need bespoke reverse-engineering (faselhd, filelions redirectors)
/// simply return empty so the UI can say "try another server" — exactly the
/// "support the top hosts, fall through the rest" approach from the plan.
class CinemaResolver {
  CinemaResolver([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';
  static const _timeout = Duration(seconds: 25);

  /// Resolves [server] to its downloadable streams (usually one; more when the
  /// host exposes several qualities, which makes the UI show a quality picker).
  /// Throws [ServerException]`('cinema_resolve_failed')` when nothing resolves.
  Future<List<CinemaStream>> resolve(CinemaServer server) async {
    if (server.youtubeLink) {
      throw const ServerException('cinema_resolve_failed');
    }

    // 1) Direct file — nothing to parse.
    if (server.isDirect) {
      return [
        CinemaStream(
          url: server.link,
          qualityLabel: server.qualityLabel ?? _labelFromUrl(server.link) ?? 'SD',
          isHls: server.link.toLowerCase().contains('.m3u8'),
        ),
      ];
    }

    // 2 + 3) Fetch the embed page and extract (raw, then unpacked). Send the
    // API-provided Referer verbatim — and NONE when it's empty: several hosts
    // (e.g. vidtube) serve a tiny block stub if they see a self-referer, so a
    // fabricated origin actively breaks them.
    final body = await _get(server.link, referer: server.header);
    if (body == null) throw const ServerException('cinema_resolve_failed');

    var urls = _extractMedia(body);
    if (urls.isEmpty) {
      final unpacked = PackedJs.unpack(body);
      if (unpacked != null) urls = _extractMedia(unpacked);
    }
    if (urls.isEmpty) throw const ServerException('cinema_resolve_failed');

    final streams = _toStreams(urls, server);
    if (streams.isEmpty) throw const ServerException('cinema_resolve_failed');
    return streams;
  }

  // ── extraction ───────────────────────────────────────────────────────────

  static final RegExp _directUrl = RegExp(
    r'''https?://[^"'\s\\<>]+?\.(?:mp4|m3u8)(?:\?[^"'\s\\<>]*)?''',
    caseSensitive: false,
  );
  static final RegExp _fileField = RegExp(
    r'''["']?(?:file|src|source)["']?\s*[:=]\s*["']([^"']+?\.(?:mp4|m3u8)[^"']*)["']''',
    caseSensitive: false,
  );

  /// Every distinct `.mp4` / `.m3u8` url in [s] (raw or unpacked JS), order
  /// preserved.
  List<String> _extractMedia(String s) {
    final seen = <String>{};
    final out = <String>[];
    void add(String? u) {
      if (u == null) return;
      final url = u.replaceAll(r'\/', '/').trim();
      if (url.startsWith('http') && seen.add(url)) out.add(url);
    }

    for (final m in _directUrl.allMatches(s)) {
      add(m.group(0));
    }
    for (final m in _fileField.allMatches(s)) {
      add(m.group(1));
    }
    return out;
  }

  /// Builds streams from the extracted urls: mp4 before m3u8 (a single file is a
  /// better download target than a playlist), de-duplicated by quality label.
  List<CinemaStream> _toStreams(List<String> urls, CinemaServer server) {
    final mp4 = urls.where((u) => u.toLowerCase().contains('.mp4'));
    final hls = urls.where((u) => u.toLowerCase().contains('.m3u8'));
    final ordered = [...mp4, ...hls];

    final byLabel = <String, CinemaStream>{};
    for (final url in ordered) {
      final isHls = url.toLowerCase().contains('.m3u8');
      final label = _labelFromUrl(url) ?? server.qualityLabel ?? 'Auto';
      byLabel.putIfAbsent(
        label,
        () => CinemaStream(url: url, qualityLabel: label, isHls: isHls),
      );
    }
    return byLabel.values.toList(growable: false);
  }

  /// A height hint from a media url (`…_1080.mp4`, `/720/`, `1080p`), or null.
  String? _labelFromUrl(String url) {
    final m = RegExp(r'(\d{3,4})\s*[pP]\b').firstMatch(url) ??
        RegExp(r'[_/-](\d{3,4})(?:[._/-]|\.mp4|\.m3u8)').firstMatch(url);
    final h = m == null ? null : int.tryParse(m.group(1)!);
    if (h != null && h >= 144 && h <= 2160) return '${h}p';
    return null;
  }

  // ── http ─────────────────────────────────────────────────────────────────

  Future<String?> _get(String url, {String? referer}) async {
    try {
      final res = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _ua,
          'Accept': '*/*',
          if (referer != null && referer.isNotEmpty) 'Referer': referer,
        },
      ).timeout(_timeout);
      return res.statusCode == 200 ? res.body : null;
    } on TimeoutException {
      throw const ServerException('cinema_resolve_failed');
    } catch (_) {
      return null;
    }
  }
}
