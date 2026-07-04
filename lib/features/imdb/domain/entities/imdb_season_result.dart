import 'package:equatable/equatable.dart';

import 'imdb_episode.dart';

/// The result of loading one season's ratings from IMDb: the requested season's
/// episodes, the full season list (for the chip selector) and the series-level
/// rating. The rating + season list come back on every call — they're cheap and
/// let the first load fill the header without a second request.
class ImdbSeasonResult extends Equatable {
  const ImdbSeasonResult({
    required this.season,
    required this.episodes,
    required this.seasons,
    this.seriesRating,
    this.seriesVotes,
  });

  /// The season these [episodes] belong to.
  final int season;
  final List<ImdbEpisode> episodes;

  /// All season numbers the title has.
  final List<int> seasons;

  final double? seriesRating;
  final int? seriesVotes;

  @override
  List<Object?> get props => [season, episodes, seasons, seriesRating, seriesVotes];
}
