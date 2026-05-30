import 'package:equatable/equatable.dart';

import 'episode_info.dart';

/// The full metadata for a single title, parsed from the Cinemeta `meta`
/// object (`/meta/{type}/{id}.json`). Drives the Browse detail page.
class MetaDetail extends Equatable {
  const MetaDetail({
    required this.id,
    required this.name,
    required this.type,
    this.poster,
    this.background,
    this.description,
    this.imdbRating,
    this.releaseInfo,
    this.runtime,
    this.genres = const [],
    this.cast = const [],
    this.episodes = const [],
  });

  final String id;
  final String name;
  final String type;
  final String? poster;
  final String? background;
  final String? description;
  final String? imdbRating;
  final String? releaseInfo;
  final String? runtime;
  final List<String> genres;
  final List<String> cast;

  /// Every episode of a series (from Cinemeta `videos`); empty for movies.
  final List<EpisodeInfo> episodes;

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    poster,
    background,
    description,
    imdbRating,
    releaseInfo,
    runtime,
    genres,
    cast,
    episodes,
  ];
}
