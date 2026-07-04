import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/errors/exceptions.dart';
import '../../../data/datasources/cinema_remote_datasource.dart';
import '../../../domain/entities/cinema_season.dart';
import 'cinema_series_state.dart';

/// Drives the series picker sheet: pick a season, then load and show its
/// episodes. EgyBest ships each episode's `videos[]` inline in
/// `series/season/{id}`, so loading a season is all that's needed before the
/// server step. Sheet-scoped: a fresh instance per opened sheet.
class CinemaSeriesCubit extends Cubit<CinemaSeriesState> {
  CinemaSeriesCubit(this._seasons, this._remote) : super(const CinemaSeriesState());

  final List<CinemaSeason> _seasons;
  final CinemaRemoteDataSource _remote;

  void init() {
    // Single season → skip the season list and load its episodes up front.
    if (_seasons.length <= 1) {
      final season = _seasons.isNotEmpty ? _seasons.first : null;
      if (season != null) {
        loadEpisodes(season);
      }
    }
  }

  Future<void> loadEpisodes(CinemaSeason season) async {
    emit(state.copyWith(
      loading: true,
      clearErrorKey: true,
      season: season,
      step: CinemaSeriesStep.episodes,
    ));
    try {
      final episodes = await _remote.season(season.id);
      if (isClosed) return;
      emit(state.copyWith(
        episodes: episodes,
        loading: false,
        clearErrorKey: episodes.isNotEmpty,
        errorKey: episodes.isEmpty ? 'cinema_no_episodes' : null,
      ));
    } on ServerException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, errorKey: e.message));
    } catch (_) {
      if (isClosed) return;
      emit(state.copyWith(loading: false, errorKey: 'cinema_unavailable'));
    }
  }

  void back() => emit(state.copyWith(
        clearErrorKey: true,
        step: CinemaSeriesStep.seasons,
      ));
}
