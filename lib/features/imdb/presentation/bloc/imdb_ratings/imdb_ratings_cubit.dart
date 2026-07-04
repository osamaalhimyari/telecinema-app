import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/imdb_ratings_datasource.dart';
import '../../../domain/entities/imdb_episode.dart';
import 'imdb_ratings_state.dart';

/// Drives the IMDb ratings dashboard: loads the first season (and with it the
/// season list + series rating) on open, then lazily fetches other seasons as
/// the viewer taps the chips, caching each so a revisit is instant. Section-
/// scoped — a fresh instance per detail page.
class ImdbRatingsCubit extends Cubit<ImdbRatingsState> {
  ImdbRatingsCubit({required this.imdbId, required this.datasource})
    : super(const ImdbRatingsState()) {
    _init();
  }

  final String imdbId;
  final ImdbRatingsDataSource datasource;

  Future<void> _init() async {
    try {
      // Season 1 exists for virtually every series and, in one call, also brings
      // back the full season list + the series rating for the header.
      var result = await datasource.fetchSeason(imdbId: imdbId, season: 1);
      if (isClosed) return;

      // Rare: a title whose seasons don't start at 1 (specials-only, etc.) —
      // fall back to its first real season so the dashboard isn't empty.
      if (result.episodes.isEmpty &&
          result.seasons.isNotEmpty &&
          !result.seasons.contains(1)) {
        result = await datasource.fetchSeason(imdbId: imdbId, season: result.seasons.first);
        if (isClosed) return;
      }

      final selected = result.episodes.isNotEmpty
          ? result.season
          : (result.seasons.isNotEmpty ? result.seasons.first : null);

      emit(
        state.copyWith(
          status: ImdbRatingsStatus.ready,
          seriesRating: result.seriesRating,
          seriesVotes: result.seriesVotes,
          seasons: result.seasons,
          selectedSeason: selected,
          episodesBySeason: {result.season: result.episodes},
        ),
      );
    } catch (_) {
      if (!isClosed) emit(state.copyWith(status: ImdbRatingsStatus.failure));
    }
  }

  Future<void> selectSeason(int season) async {
    if (season == state.selectedSeason) return;
    // Already fetched → switch instantly.
    if (state.episodesBySeason.containsKey(season)) {
      emit(state.copyWith(selectedSeason: season, seasonLoading: false));
      return;
    }
    emit(state.copyWith(selectedSeason: season, seasonLoading: true));
    try {
      final result = await datasource.fetchSeason(imdbId: imdbId, season: season);
      if (isClosed) return;
      final cache = Map<int, List<ImdbEpisode>>.from(state.episodesBySeason)
        ..[season] = result.episodes;
      // Only clear the spinner if this is still the season on screen (guards
      // against a slow earlier season landing after a newer tap).
      emit(
        state.copyWith(
          episodesBySeason: cache,
          seasonLoading: state.selectedSeason == season ? false : state.seasonLoading,
        ),
      );
    } catch (_) {
      if (!isClosed && state.selectedSeason == season) {
        emit(state.copyWith(seasonLoading: false));
      }
    }
  }
}
