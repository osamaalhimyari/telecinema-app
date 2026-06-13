import 'package:equatable/equatable.dart';

import '../../../domain/entities/topcinema_series.dart';
import '../../../domain/entities/topcinema_source.dart';

/// The drill-down step currently shown in the sheet.
enum TopcinemaStep { seasons, episodes, qualities }

/// State for the series seasons/episodes/qualities drill-down sheet.
class TopcinemaSeasonsState extends Equatable {
  const TopcinemaSeasonsState({
    this.step = TopcinemaStep.seasons,
    this.loading = true,
    this.errorKey,
    this.seasons = const [],
    this.episodes = const [],
    this.sources = const [],
    this.selectedSeason,
    this.selectedEpisode,
  });

  final TopcinemaStep step;
  final bool loading;
  final String? errorKey;

  final List<TopcinemaSeason> seasons;
  final List<TopcinemaEpisode> episodes;
  final List<TopcinemaSource> sources;

  final TopcinemaSeason? selectedSeason;
  final TopcinemaEpisode? selectedEpisode;

  TopcinemaSeasonsState copyWith({
    TopcinemaStep? step,
    bool? loading,
    String? errorKey,
    bool clearErrorKey = false,
    List<TopcinemaSeason>? seasons,
    List<TopcinemaEpisode>? episodes,
    List<TopcinemaSource>? sources,
    TopcinemaSeason? selectedSeason,
    bool clearSelectedSeason = false,
    TopcinemaEpisode? selectedEpisode,
    bool clearSelectedEpisode = false,
  }) {
    return TopcinemaSeasonsState(
      step: step ?? this.step,
      loading: loading ?? this.loading,
      errorKey: clearErrorKey ? null : (errorKey ?? this.errorKey),
      seasons: seasons ?? this.seasons,
      episodes: episodes ?? this.episodes,
      sources: sources ?? this.sources,
      selectedSeason: clearSelectedSeason ? null : (selectedSeason ?? this.selectedSeason),
      selectedEpisode: clearSelectedEpisode ? null : (selectedEpisode ?? this.selectedEpisode),
    );
  }

  @override
  List<Object?> get props => [
    step,
    loading,
    errorKey,
    seasons,
    episodes,
    sources,
    selectedSeason,
    selectedEpisode,
  ];
}
