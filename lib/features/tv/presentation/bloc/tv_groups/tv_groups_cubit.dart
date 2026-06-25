import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/errors/exceptions.dart';
import '../../../data/tv_api.dart';
import 'tv_groups_state.dart';

/// Loads the live-TV category tree for the TV tab. A pull-to-refresh forces a
/// re-fetch so the per-channel stream tokens (which expire within hours) are
/// renewed.
class TvGroupsCubit extends Cubit<TvGroupsState> {
  TvGroupsCubit(this._api) : super(const TvGroupsState());

  final TvApi _api;

  Future<void> load({bool forceRefresh = false}) async {
    if (state.isLoading) return;
    emit(state.copyWith(status: TvGroupsStatus.loading, clearError: true));
    try {
      final groups = await _api.fetchTree(forceRefresh: forceRefresh);
      emit(state.copyWith(
        status: TvGroupsStatus.success,
        groups: groups,
        clearError: true,
      ));
    } on ServerException catch (e) {
      emit(state.copyWith(status: TvGroupsStatus.failure, errorKey: e.message));
    } catch (_) {
      emit(state.copyWith(status: TvGroupsStatus.failure, errorKey: 'error_unknown'));
    }
  }

  Future<void> refresh() => load(forceRefresh: true);
}
