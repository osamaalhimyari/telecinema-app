import 'package:equatable/equatable.dart';

/// A single torrent candidate for a title: a ready-to-use [magnet] plus the
/// swarm health used to rank candidates. Built in the data layer from an
/// apibay result; the magnet is assembled from [infoHash] + public trackers.
class TorrentOption extends Equatable {
  const TorrentOption({
    required this.name,
    required this.infoHash,
    required this.magnet,
    this.seeders = 0,
    this.leechers = 0,
    this.sizeBytes = 0,
  });

  final String name;
  final String infoHash;
  final String magnet;
  final int seeders;
  final int leechers;
  final int sizeBytes;

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
  List<Object?> get props => [name, infoHash, magnet, seeders, leechers, sizeBytes];
}
