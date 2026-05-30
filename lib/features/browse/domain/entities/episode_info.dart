import 'package:equatable/equatable.dart';

/// One episode of a series, taken from the Cinemeta `videos` list. Drives the
/// series source picker: every episode is shown (even seasons that only exist
/// as packs on the torrent side), and its torrent is resolved on tap.
class EpisodeInfo extends Equatable {
  const EpisodeInfo({required this.season, required this.episode, this.name});

  final int season;
  final int episode;
  final String? name;

  @override
  List<Object?> get props => [season, episode, name];
}
