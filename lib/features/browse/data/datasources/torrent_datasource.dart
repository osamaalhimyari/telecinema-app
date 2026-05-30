import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '/core/errors/exceptions.dart';
import '../../domain/entities/torrent_option.dart';
import '../json_parse.dart';
import '../torrent_classifier.dart';

/// Finds magnets for a title by querying apibay (The Pirate Bay's JSON API) by
/// IMDB id. The magnet is assembled locally from each result's `info_hash` plus
/// a set of public trackers, so no second (CORS-prone) lookup is needed.
///
/// Throws [ServerException] with a stable error key on transport failure.
abstract class TorrentDataSource {
  /// Every *video* torrent for [imdbId], most-seeded first. Empty when the
  /// swarm has nothing. Each option is classified (season/episode, quality,
  /// pack) so the caller can group them into episodes or qualities.
  Future<List<TorrentOption>> findAll({required String imdbId, required String title});

  /// Free-text apibay search (e.g. `The Boys S01E01`), most-seeded first. Used
  /// to resolve a single episode that the IMDB-id search only had as a pack.
  Future<List<TorrentOption>> searchByQuery(String query);
}

class TorrentDataSourceImpl implements TorrentDataSource {
  TorrentDataSourceImpl([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apibay = 'https://apibay.org/q.php';
  static const Duration _timeout = Duration(seconds: 20);

  /// apibay's empty-result sentinel.
  static const String _zeroHash = '0000000000000000000000000000000000000000';

  /// Public trackers appended to every built magnet to seed peer discovery.
  static const List<String> _trackers = [
    'udp://tracker.opentrackr.org:1337/announce',
    'udp://tracker.openbittorrent.com:6969/announce',
    'udp://open.stealth.si:80/announce',
    'udp://exodus.desync.com:6969/announce',
    'udp://tracker.torrent.eu.org:451/announce',
    'udp://explodie.org:6969/announce',
    'udp://tracker.coppersurfer.tk:6969/announce',
  ];

  /// Filename hints that mark a result as a watchable video.
  static const List<String> _videoHints = [
    'mkv', 'mp4', 'avi', 'x264', 'x265', 'h264', 'h265', 'hevc', 'xvid',
    'bluray', 'blu-ray', 'brrip', 'bdrip', 'webrip', 'web-dl', 'web dl',
    'hdtv', 'hdrip', 'dvdrip', '2160p', '1080p', '720p', '480p', 'yify', 'yts',
  ];

  @override
  Future<List<TorrentOption>> findAll({required String imdbId, required String title}) async {
    final results = await _query(imdbId);
    // Most seeders first; the picker selects the best within each group by
    // taking the first, so this ordering carries through grouping.
    results.sort((a, b) => b.seeders.compareTo(a.seeders));
    return results;
  }

  @override
  Future<List<TorrentOption>> searchByQuery(String query) async {
    final results = await _query(query);
    results.sort((a, b) => b.seeders.compareTo(a.seeders));
    return results;
  }

  Future<List<TorrentOption>> _query(String query) async {
    final uri = Uri.parse('$_apibay?q=${Uri.encodeQueryComponent(query)}');
    try {
      final res = await _client.get(uri).timeout(_timeout);
      if (res.statusCode != 200) {
        throw ServerException('error_request_failed', statusCode: res.statusCode);
      }
      final body = jsonDecode(res.body);
      if (body is! List) return const [];

      final out = <TorrentOption>[];
      for (final raw in body.whereType<Map>()) {
        final m = Map<String, dynamic>.from(raw);
        final hash = asString(m['info_hash']);
        final name = asString(m['name']);
        if (hash == null || name == null) continue;
        if (hash.toLowerCase() == _zeroHash) continue; // "No results returned"
        if (!_isVideo(name, asString(m['category']))) continue;

        final se = parseSeasonEpisode(name);
        out.add(
          TorrentOption(
            name: name,
            infoHash: hash,
            magnet: _buildMagnet(hash, name),
            seeders: asInt(m['seeders']),
            leechers: asInt(m['leechers']),
            sizeBytes: asInt(m['size']),
            season: se.season,
            episode: se.episode,
            quality: parseQuality(name),
            isPack: isPackName(name),
          ),
        );
      }
      return out;
    } on ServerException {
      rethrow;
    } on TimeoutException {
      throw const ServerException('error_timeout');
    } catch (e) {
      throw ServerException('error_unknown', cause: e);
    }
  }

  /// apibay video categories are `2xx`; otherwise fall back to filename hints.
  bool _isVideo(String name, String? category) {
    if (category != null && category.startsWith('2')) return true;
    final lower = name.toLowerCase();
    return _videoHints.any(lower.contains);
  }

  static String _buildMagnet(String hash, String name) {
    final dn = Uri.encodeQueryComponent(name);
    final trackers = _trackers
        .map((t) => '&tr=${Uri.encodeQueryComponent(t)}')
        .join();
    return 'magnet:?xt=urn:btih:$hash&dn=$dn$trackers';
  }
}
