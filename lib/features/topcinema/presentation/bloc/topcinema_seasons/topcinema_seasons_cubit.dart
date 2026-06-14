import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/errors/exceptions.dart';
import '../../../data/datasources/topcinema_remote_datasource.dart';
import '../../../domain/entities/topcinema_series.dart';
import 'topcinema_seasons_state.dart';

/// Holds the series picker sheet's drill-down state (seasons → episodes →
/// qualities) and runs the on-device parses/resolves. Sheet-scoped: a fresh
/// instance per picker.
class TopcinemaSeasonsCubit extends Cubit<TopcinemaSeasonsState> {
  TopcinemaSeasonsCubit({
    required this.title,
    required this.name,
    required this.datasource,
  }) : super(const TopcinemaSeasonsState()) {
    _loadByName();
  }

  final String title;
  final String name;
  final TopcinemaRemoteDataSource datasource;

  void _setError(Object error) {
    if (isClosed) return;
    emit(
      state.copyWith(
        loading: false,
        errorKey: error is ServerException ? error.message : 'topcinema_unavailable',
      ),
    );
  }

  /// Step 1: load the title → its seasons (and the entry season's episodes). A
  /// single-season title skips straight to the episodes step.
  Future<void> _loadByName() async {
    try {
      final s = await datasource.series(name: name);
      if (isClosed) return;
      if (s.seasons.length <= 1) {
        emit(
          state.copyWith(
            seasons: s.seasons,
            clearErrorKey: true,
            episodes: s.episodes,
            selectedSeason: s.seasons.isNotEmpty ? s.seasons.first : null,
            clearSelectedSeason: s.seasons.isEmpty,
            step: TopcinemaStep.episodes,
            loading: false,
          ),
        );
      } else {
        emit(
          state.copyWith(
            seasons: s.seasons,
            clearErrorKey: true,
            step: TopcinemaStep.seasons,
            loading: false,
          ),
        );
      }
    } catch (e) {
      _setError(e);
    }
  }

  /// Step 2: a season was tapped → load and show its episodes.
  Future<void> openSeason(TopcinemaSeason season) async {
    emit(
      state.copyWith(
        loading: true,
        clearErrorKey: true,
        selectedSeason: season,
        step: TopcinemaStep.episodes,
      ),
    );
    try {
      final s = await datasource.series(url: season.url);
      if (isClosed) return;
      emit(
        state.copyWith(
          episodes: s.episodes,
          seasons: s.seasons.isNotEmpty ? s.seasons : null,
          loading: false,
        ),
      );
    } catch (e) {
      _setError(e);
    }
  }

  /// Step 3: an episode was tapped → resolve and show its qualities.
  Future<void> openEpisode(TopcinemaEpisode ep) async {
    emit(
      state.copyWith(
        loading: true,
        clearErrorKey: true,
        selectedEpisode: ep,
        step: TopcinemaStep.qualities,
      ),
    );
    try {
      final sources = await datasource.resolveEpisode(ep.url);
      if (isClosed) return;
      emit(
        state.copyWith(
          sources: sources,
          loading: false,
          errorKey: sources.isEmpty ? 'topcinema_not_found' : null,
        ),
      );
    } catch (e) {
      _setError(e);
    }
  }

  void back() {
    switch (state.step) {
      case TopcinemaStep.qualities:
        emit(state.copyWith(clearErrorKey: true, step: TopcinemaStep.episodes));
      case TopcinemaStep.episodes:
        emit(
          state.copyWith(
            clearErrorKey: true,
            step: state.seasons.length > 1 ? TopcinemaStep.seasons : TopcinemaStep.episodes,
          ),
        );
      case TopcinemaStep.seasons:
        emit(state.copyWith(clearErrorKey: true));
    }
  }

  bool get canGoBack =>
      state.step == TopcinemaStep.qualities ||
      (state.step == TopcinemaStep.episodes && state.seasons.length > 1);
}
