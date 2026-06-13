import 'package:equatable/equatable.dart';

import '../../../domain/entities/cinema_season.dart';

/// The two drill-down steps of the series picker.
enum CinemaSeriesStep { seasons, episodes }

/// State for the series picker sheet: which step is showing, whether episodes
/// are loading, an optional error key, the loaded episodes, and the active
/// season (used for the `S01E02` label and the subtitle breadcrumb).
class CinemaSeriesState extends Equatable {
  const CinemaSeriesState({
    this.step = CinemaSeriesStep.seasons,
    this.loading = false,
    this.errorKey,
    this.episodes = const [],
    this.season,
  });

  final CinemaSeriesStep step;
  final bool loading;
  final String? errorKey;
  final List<CinemaEpisode> episodes;
  final CinemaSeason? season;

  CinemaSeriesState copyWith({
    CinemaSeriesStep? step,
    bool? loading,
    String? errorKey,
    bool clearErrorKey = false,
    List<CinemaEpisode>? episodes,
    CinemaSeason? season,
  }) {
    return CinemaSeriesState(
      step: step ?? this.step,
      loading: loading ?? this.loading,
      errorKey: clearErrorKey ? null : (errorKey ?? this.errorKey),
      episodes: episodes ?? this.episodes,
      season: season ?? this.season,
    );
  }

  @override
  List<Object?> get props => [step, loading, errorKey, episodes, season];
}
