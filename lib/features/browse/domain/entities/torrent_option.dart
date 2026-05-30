import 'package:equatable/equatable.dart';

/// A single torrent candidate for a title: a ready-to-use [magnet] plus the
/// swarm health used to rank candidates, and the bits of meaning parsed out of
/// the release [name] (season/episode for series, [quality]/[isPack] for
/// movies) that let the picker group results. Built in the data layer from an
/// apibay result; the magnet is assembled from [infoHash] + public trackers.
class TorrentOption extends Equatable {
  const TorrentOption({
    required this.name,
    required this.infoHash,
    required this.magnet,
    this.seeders = 0,
    this.leechers = 0,
    this.sizeBytes = 0,
    this.season,
    this.episode,
    this.quality = 'SD',
    this.isPack = false,
  });

  final String name;
  final String infoHash;
  final String magnet;
  final int seeders;
  final int leechers;
  final int sizeBytes;

  /// Season number parsed from the name (set for both episodes and season
  /// packs), or null for movies / unrecognised names.
  final int? season;

  /// Episode number parsed from the name. Non-null only for a single episode;
  /// null for season packs and movies.
  final int? episode;

  /// Coarse resolution bucket — `4K`, `1080p`, `720p`, `480p`, or `SD`.
  final String quality;

  /// True when the release bundles multiple films (trilogy / complete set).
  final bool isPack;

  /// A single episode (has both season and episode numbers).
  bool get isEpisode => episode != null;

  /// A whole-season pack (season known, no single episode).
  bool get isSeasonPack => episode == null && season != null;

  /// Human-readable size (e.g. `1.6 GB`), or empty when unknown.
  String get humanSize {
    if (sizeBytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    var value = sizeBytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < units.length - 1) {
      value /= 1024;
      unit++;
    }
    final fixed = value >= 100 || unit == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
    return '$fixed ${units[unit]}';
  }

  @override
  List<Object?> get props => [
    name,
    infoHash,
    magnet,
    seeders,
    leechers,
    sizeBytes,
    season,
    episode,
    quality,
    isPack,
  ];
}
