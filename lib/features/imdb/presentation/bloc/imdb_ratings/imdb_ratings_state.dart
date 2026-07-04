import 'package:equatable/equatable.dart';

import '../../../domain/entities/imdb_episode.dart';

enum ImdbRatingsStatus { loading, ready, failure }

/// State for the IMDb ratings dashboard: the series rating, the season list, and
/// a per-season episode cache so switching back to a loaded season is instant.
class ImdbRatingsState extends Equatable {
  const ImdbRatingsState({
    this.status = ImdbRatingsStatus.loading,
    this.seriesRating,
    this.seriesVotes,
    this.seasons = const [],
    this.selectedSeason,
    this.episodesBySeason = const {},
    this.seasonLoading = false,
  });

  final ImdbRatingsStatus status;
  final double? seriesRating;
  final int? seriesVotes;
  final List<int> seasons;
  final int? selectedSeason;

  /// Episodes already fetched, keyed by season number.
  final Map<int, List<ImdbEpisode>> episodesBySeason;

  /// True while a newly-selected season's episodes are being fetched.
  final bool seasonLoading;

  List<ImdbEpisode> get episodes =>
      selectedSeason == null ? const [] : (episodesBySeason[selectedSeason] ?? const []);

  /// Nothing worth showing (a movie, an unknown id, or a load failure) — the
  /// section collapses in these cases so the page stays clean.
  bool get isEmpty =>
      status == ImdbRatingsStatus.failure ||
      (status == ImdbRatingsStatus.ready && seasons.isEmpty);

  ImdbRatingsState copyWith({
    ImdbRatingsStatus? status,
    double? seriesRating,
    int? seriesVotes,
    List<int>? seasons,
    int? selectedSeason,
    Map<int, List<ImdbEpisode>>? episodesBySeason,
    bool? seasonLoading,
  }) {
    return ImdbRatingsState(
      status: status ?? this.status,
      seriesRating: seriesRating ?? this.seriesRating,
      seriesVotes: seriesVotes ?? this.seriesVotes,
      seasons: seasons ?? this.seasons,
      selectedSeason: selectedSeason ?? this.selectedSeason,
      episodesBySeason: episodesBySeason ?? this.episodesBySeason,
      seasonLoading: seasonLoading ?? this.seasonLoading,
    );
  }

  @override
  List<Object?> get props => [
    status,
    seriesRating,
    seriesVotes,
    seasons,
    selectedSeason,
    episodesBySeason,
    seasonLoading,
  ];
}
