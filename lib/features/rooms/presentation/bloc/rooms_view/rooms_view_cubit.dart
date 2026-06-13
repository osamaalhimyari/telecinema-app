import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'rooms_view_state.dart';

/// Holds the home grid's local UI state: the active collection scope
/// (all / favorites / recent) and the search field's controller. The
/// search text itself drives [RoomsListCubit.setQuery]; this cubit only
/// owns the controller so the clear-button can read/clear it.
class RoomsViewCubit extends Cubit<RoomsViewState> {
  RoomsViewCubit() : super(const RoomsViewState());

  final TextEditingController search = TextEditingController();

  /// Switches the favorites/recent collection scope on top of the cubit's
  /// already search- and category-filtered visible rooms.
  void setCollection(RoomsCollection collection) =>
      emit(state.copyWith(collection: collection));

  /// Clears the search field's text (the caller still resets the query on
  /// [RoomsListCubit]).
  void clear() => search.clear();

  @override
  Future<void> close() {
    search.dispose();
    return super.close();
  }
}
