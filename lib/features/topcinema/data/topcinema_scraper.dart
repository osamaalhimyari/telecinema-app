import 'dart:async';

import 'package:http/http.dart' as http;

import '/core/config/endpoints.dart';
import '/core/errors/exceptions.dart';
import '../domain/entities/topcinema_series.dart';
import '../domain/entities/topcinema_source.dart';

/// ISOLATED on-device topcinema scraper.
///
/// Runs in the app (like the Cinemeta datasource) rather than on the backend,
/// because the deployed server's datacenter IP is blocked by topcinema while the
/// phone's own network reaches it fine. It walks the site exactly as a browser
/// would and returns parsed seasons/episodes and direct, downloadable MP4 links
/// resolved from the "vidtube.one" file host. Only the final CDN link is handed
/// to the server (for the `download` room) — the server never touches topcinema.
///
/// Throws [ServerException] with a stable key (`topcinema_not_found` /
/// `topcinema_unavailable`) so the UI can translate it.
class TopcinemaScraper {
  TopcinemaScraper([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';
  /// Mirror hosts, tried in order — a dead/blocked mirror falls through to the
  /// next. [_base] stays the canonical one (used as the Referer when resolving
  /// the file host).
  static const _hosts = Endpoints.topcinemaHosts;
  static const _base = Endpoints.topcinema;
  static const _timeout = Duration(seconds: 25);

  /// `href="…"` links pointing back at any configured mirror host — so links are
  /// captured whichever mirror served the page. Adding a host in `endpoints.dart`
  /// is the only edit needed.
  static final RegExp _linkRe =
      RegExp('href="((?:${_hosts.map(RegExp.escape).join('|')})/[^"]+)"');

  /// Arabic season ordinals as they appear in the url (الموسم الاول … العاشر).
  static const _ordinals = [
    '', 'الاول', 'الثاني', 'الثالث', 'الرابع', 'الخامس',
    'السادس', 'السابع', 'الثامن', 'التاسع', 'العاشر',
  ];

  // ---- public API --------------------------------------------------------

  /// Opens a series by editable [name] (its url slug). Tries the canonical
  /// season-one page, then the base series page, then search. Returns the
  /// seasons list + that page's episodes.
  ///
  /// When [host] is given the search is pinned to that mirror (the viewer picked
  /// it) — no failover to the others; otherwise every mirror is tried in order.
  Future<TopcinemaSeries> seriesByName(String name, {String? host}) async {
    final slug = _slugify(name);
    final series = await _acrossHosts((base) => _seriesByNameOn(base, slug), host: host);
    if (series == null) throw const ServerException('topcinema_not_found');
    return series;
  }

  /// One mirror's attempt at [seriesByName]. Returns null when this host has no
  /// match (so the caller can fail over to the next mirror).
  Future<TopcinemaSeries?> _seriesByNameOn(String base, String slug) async {
    final candidates = [
      '$base/series/${Uri.encodeComponent('مسلسل-$slug-الموسم-الاول-مترجم')}/',
      '$base/series/${Uri.encodeComponent('مسلسل-$slug-مترجم')}/',
    ];
    for (final url in candidates) {
      final html = await _get(url);
      if (html != null && _looksLikeSeries(html, slug)) {
        return _parseSeries(url, html);
      }
    }
    // Search fallback: any series/episode link for this title.
    final results = await _get('$base/?s=${Uri.encodeQueryComponent(slug.replaceAll('-', ' '))}');
    if (results != null) {
      final series = _links(results).where((l) =>
          l.dec.contains('/series/') && l.dec.contains('مسلسل-'));
      for (final l in series) {
        final html = await _get(l.raw);
        if (html != null) return _parseSeries(l.raw, html);
      }
      final ep = _links(results).firstWhereOrNull(
          (l) => l.dec.contains('الحلقة') && l.dec.contains('مسلسل-'));
      final epSlug = ep == null ? null : _slugOf(ep.dec);
      if (epSlug != null) {
        final url = '$base/series/${Uri.encodeComponent('مسلسل-$epSlug-الموسم-الاول-مترجم')}/';
        final html = await _get(url);
        if (html != null) return _parseSeries(url, html);
      }
    }
    return null;
  }

  /// Parses a specific season page (when the user switches seasons).
  Future<TopcinemaSeries> seasonPage(String url) async {
    final html = await _get(url);
    if (html == null) throw const ServerException('topcinema_not_found');
    return _parseSeries(url, html);
  }

  /// Resolves a parsed episode page url to its downloadable sources.
  Future<List<TopcinemaSource>> resolveEpisode(String episodeUrl) async {
    final sources = await _resolvePage(episodeUrl);
    if (sources.isEmpty) throw const ServerException('topcinema_not_found');
    return sources;
  }

  /// Resolves a movie (by editable name slug) to its sources. [host] pins the
  /// mirror when the viewer picked one (see [seriesByName]).
  Future<List<TopcinemaSource>> resolveMovie(String name, {String? host}) async {
    final slug = _slugify(name);
    final sources = await _acrossHosts((base) => _resolveMovieOn(base, slug), host: host);
    if (sources == null || sources.isEmpty) {
      throw const ServerException('topcinema_not_found');
    }
    return sources;
  }

  /// One mirror's attempt at [resolveMovie]; null when this host has no sources.
  Future<List<TopcinemaSource>?> _resolveMovieOn(String base, String slug) async {
    final candidates = ['$base/${Uri.encodeComponent('فيلم-$slug-مترجم')}/'];
    final results = await _get('$base/?s=${Uri.encodeQueryComponent(slug.replaceAll('-', ' '))}');
    if (results != null) {
      final film = _links(results)
          .firstWhereOrNull((l) => l.dec.contains('فيلم-') && !l.dec.contains('الحلقة'));
      if (film != null) candidates.add(film.raw);
    }
    for (final page in candidates) {
      final sources = await _resolvePage(page);
      if (sources.isNotEmpty) return sources;
    }
    return null;
  }

  // ---- parsing -----------------------------------------------------------

  bool _looksLikeSeries(String html, String slug) =>
      _links(html).any((l) => _slugOf(l.dec) == slug && l.dec.contains('الحلقة'));

  TopcinemaSeries _parseSeries(String url, String html) {
    final slug = _slugOf(Uri.decodeFull(url));
    if (slug == null) throw const ServerException('topcinema_not_found');

    // Seasons — deduped by ordinal (the page links each season several times).
    final seenSeason = <String>{};
    final seasons = <TopcinemaSeason>[];
    for (final l in _links(html)) {
      if (!l.dec.contains('/series/') || !l.dec.contains('الموسم') || l.dec.contains('الحلقة')) {
        continue;
      }
      if (_slugOf(l.dec) != slug) continue;
      final ord = RegExp(r'الموسم-(.+?)-مترجم').firstMatch(l.dec)?.group(1) ?? '';
      if (ord.isEmpty || seenSeason.contains(ord)) continue;
      seenSeason.add(ord);
      seasons.add(TopcinemaSeason(
        number: _ordinals.indexOf(ord) > 0 ? _ordinals.indexOf(ord) : 0,
        title: 'الموسم $ord',
        url: l.raw,
      ));
    }
    seasons.sort((a, b) => a.number.compareTo(b.number));

    // Episodes — deduped, numbers read from the real urls.
    final seenEp = <String>{};
    final episodes = <TopcinemaEpisode>[];
    for (final l in _links(html)) {
      if (!l.dec.contains('الحلقة') || !l.dec.contains('مترجمة')) continue;
      if (_slugOf(l.dec) != slug) continue;
      if (seenEp.contains(l.raw)) continue;
      seenEp.add(l.raw);
      final n = int.tryParse(RegExp(r'الحلقة-(\d+)').firstMatch(l.dec)?.group(1) ?? '0') ?? 0;
      episodes.add(TopcinemaEpisode(number: n, title: 'الحلقة $n', url: l.raw));
    }
    episodes.sort((a, b) => a.number.compareTo(b.number));

    if (seasons.isEmpty && episodes.isEmpty) {
      throw const ServerException('topcinema_not_found');
    }
    return TopcinemaSeries(page: url, seasons: seasons, episodes: episodes);
  }

  /// episode/movie page → `/download/` → vidtube host → all quality variants.
  Future<List<TopcinemaSource>> _resolvePage(String pageUrl) async {
    final dlUrl = pageUrl.endsWith('/') ? '${pageUrl}download/' : '$pageUrl/download/';
    final dl = await _get(dlUrl);
    if (dl == null) return const [];
    // The file host rotates its subdomain (`vidtube.one` → `down.vidtube.one` →
    // …) just like topcinema's own mirror, so match any subdomain.
    final vt = RegExp(
              r'href="(https://(?:[\w-]+\.)?vidtube\.one/d/[^"]+\.html)"[^>]*class="[^"]*proServer',
              caseSensitive: false)
          .firstMatch(dl)
          ?.group(1) ??
      RegExp(r'href="(https://(?:[\w-]+\.)?vidtube\.one/d/[^"]+\.html)"', caseSensitive: false)
          .firstMatch(dl)
          ?.group(1);
    if (vt == null) return const [];
    return _resolveVidtube(vt);
  }

  Future<List<TopcinemaSource>> _resolveVidtube(String vidtubeHtmlUrl) async {
    final id = RegExp(r'/d/([^.]+)\.html').firstMatch(vidtubeHtmlUrl)?.group(1);
    if (id == null) return const [];
    // Resolve quality variants against whatever subdomain served this page.
    final origin = Uri.parse(vidtubeHtmlUrl).origin;
    final body = await _get(vidtubeHtmlUrl, referer: '$_base/');
    if (body == null) return const [];

    final variants = RegExp('href="/d/(${id}_([xhnl]))"[^>]*>(.*?)</a>', dotAll: true)
        .allMatches(body)
        .map((m) => (key: m.group(2)!, label: _clean(m.group(3)!)))
        .toList();
    if (variants.isEmpty) return const [];

    final resolved = await Future.wait(variants.map((v) async {
      final vb = await _get('$origin/d/${id}_${v.key}', referer: vidtubeHtmlUrl);
      final url = vb == null
          ? null
          : RegExp(r'https?://[^"' "'" r'\s]+\.mp4[^"' "'" r'\s]*').firstMatch(vb)?.group(0);
      if (url == null) return null;
      final mb = RegExp(r'([\d.]+)\s*MB').firstMatch(v.label);
      final gb = RegExp(r'([\d.]+)\s*GB').firstMatch(v.label);
      return TopcinemaSource(
        quality: v.key,
        label: v.label,
        url: url,
        resolution: RegExp(r'(\d{3,4}x\d{3,4})').firstMatch(v.label)?.group(1),
        sizeMb: gb != null
            ? (double.tryParse(gb.group(1)!) ?? 0) * 1024
            : (mb != null ? double.tryParse(mb.group(1)!) : null),
      );
    }));
    return resolved.whereType<TopcinemaSource>().toList();
  }

  // ---- helpers -----------------------------------------------------------

  /// Runs [attempt] against each mirror host in turn, returning the first
  /// non-null result. A host that is unreachable (timeout / network error) is
  /// skipped so a dead mirror falls through to the next; only if *every* host is
  /// unreachable is the connectivity error surfaced. A reachable host that
  /// simply has no match returns null and the caller decides (`not_found`).
  ///
  /// When [host] is given, only that mirror is tried (the viewer pinned it) —
  /// there is no failover, so a miss there surfaces `not_found` rather than
  /// silently searching the other domain.
  Future<T?> _acrossHosts<T>(Future<T?> Function(String base) attempt, {String? host}) async {
    final hosts = host == null ? _hosts : [host];
    ServerException? lastError;
    for (final base in hosts) {
      try {
        final result = await attempt(base);
        if (result != null) return result;
      } on ServerException catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
    return null;
  }

  /// Fetches a url with a browser UA. Returns null on a non-200 / network error
  /// (callers treat that as "no source here" and fall through).
  Future<String?> _get(String url, {String? referer}) async {
    try {
      final res = await _client.get(
        Uri.parse(url),
        headers: {'User-Agent': _ua, 'Referer': ?referer},
      ).timeout(_timeout);
      return res.statusCode == 200 ? res.body : null;
    } on TimeoutException {
      throw const ServerException('topcinema_unavailable');
    } catch (_) {
      throw const ServerException('topcinema_unavailable');
    }
  }

  List<({String raw, String dec})> _links(String html) {
    final out = <({String raw, String dec})>[];
    for (final m in _linkRe.allMatches(html)) {
      final raw = m.group(1)!;
      String dec;
      try {
        dec = Uri.decodeFull(raw);
      } catch (_) {
        dec = raw;
      }
      out.add((raw: raw, dec: dec));
    }
    return out;
  }

  String? _slugOf(String dec) =>
      RegExp(r'مسلسل-(.+?)-(?:الموسم|مترجم)').firstMatch(dec)?.group(1);

  String _slugify(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp("['’`]"), '')
      .replaceAll(RegExp(r'\s+'), '-');

  String _clean(String s) =>
      s.replaceAll(RegExp(r'<[^>]+>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}

extension _FirstWhereOrNull<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
