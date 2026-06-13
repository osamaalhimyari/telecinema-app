import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/errors/exceptions.dart';
import '/core/localization/translation_keys.dart';
import '../../../data/datasources/youtube_remote_datasource.dart';
import 'youtube_search_state.dart';

/// Drives the YouTube search tab: debounces the query, searches on-device via
/// the data source, and guards against out-of-order responses. Owns the search
/// field's controller + the debounce timer so the page can be a plain
/// StatelessWidget.
class YoutubeSearchCubit extends Cubit<YoutubeSearchState> {
  YoutubeSearchCubit(this._datasource) : super(const YoutubeSearchState());

  final YoutubeRemoteDataSource _datasource;

  /// Owned by the cubit so it survives widget rebuilds; disposed in [close].
  final TextEditingController searchController = TextEditingController();

  Timer? _debounce;

  /// Guards against out-of-order responses: only the latest query's result is
  /// applied (a slow earlier search can't overwrite a newer one).
  int _requestId = 0;

  void onChanged(String value) {
    // Refresh the clear button by tracking the live query.
    emit(state.copyWith(query: value));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => search(value.trim()));
  }

  void clear() {
    _debounce?.cancel();
    searchController.clear();
    emit(state.copyWith(
      query: '',
      results: const [],
      loading: false,
      clearErrorKey: true,
    ));
  }

  Future<void> search(String query) async {
    if (query.isEmpty) {
      emit(state.copyWith(
        results: const [],
        loading: false,
        clearErrorKey: true,
      ));
      return;
    }
    final id = ++_requestId;
    emit(state.copyWith(loading: true, clearErrorKey: true));
    try {
      final results = await _datasource.search(query);
      if (isClosed || id != _requestId) return;
      emit(state.copyWith(
        results: results,
        loading: false,
        clearErrorKey: results.isNotEmpty,
        errorKey: results.isEmpty ? TranslationKeys.youtubeNoResults : null,
      ));
    } on ServerException catch (e) {
      if (isClosed || id != _requestId) return;
      emit(state.copyWith(loading: false, errorKey: e.message));
    } catch (_) {
      if (isClosed || id != _requestId) return;
      emit(state.copyWith(loading: false, errorKey: TranslationKeys.youtubeUnavailable));
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    searchController.dispose();
    return super.close();
  }
}
