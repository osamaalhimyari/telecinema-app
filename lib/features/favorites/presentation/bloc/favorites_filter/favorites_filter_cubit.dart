import 'package:flutter_bloc/flutter_bloc.dart';

import 'favorites_filter_state.dart';

/// Owns the Favorites tab's source filter (null = all, otherwise
/// `cinemeta` / `egybest`), so the page can be a plain StatelessWidget.
class FavoritesFilterCubit extends Cubit<FavoritesFilterState> {
  FavoritesFilterCubit() : super(const FavoritesFilterState());

  /// Picks the active source filter; [source] of null shows everything.
  void select(String? source) {
    emit(source == null ? state.copyWith(clearSource: true) : state.copyWith(source: source));
  }
}
