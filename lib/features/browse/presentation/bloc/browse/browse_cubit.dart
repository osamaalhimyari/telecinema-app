import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/browse_category.dart';
import '../../../domain/entities/catalog_item.dart';
import '../../../domain/usecases/get_catalog_usecase.dart';
import '../../../domain/usecases/search_catalog_usecase.dart';
import 'browse_state.dart';

/// Drives the Browse grid: category toggle (All/Movies/Series), debounced title
/// search, dynamic genre chips and skip-based infinite scroll. "All" fans out to
/// both the movie and series catalogues and merges them, de-duplicated by id.
class BrowseCubit extends Cubit<BrowseState> {
  BrowseCubit(this._getCatalog, this._search) : super(const BrowseState());

  final GetCatalogUseCase _getCatalog;
  final SearchCatalogUseCase _search;

  Timer? _debounce;

  /// Initial load / full reload for the current category + query.
  Future<void> load() async {
    emit(
      state.copyWith(
        status: BrowseStatus.loading,
        items: const [],
        skip: 0,
        hasMore: true,
        loadingMore: false,
        clearGenre: true,
        clearError: true,
      ),
    );
    await _fetch(reset: true);
  }

  void setCategory(BrowseCategory category) {
    if (category == state.category) return;
    emit(state.copyWith(category: category));
    load();
  }

  /// Debounced so typing doesn't fire a request per keystroke.
  void setQuery(String raw) {
    final query = raw.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (query == state.query) return;
      emit(state.copyWith(query: query));
      load();
    });
  }

  /// Local-only genre filter — no refetch.
  void setGenre(String? genre) =>
      emit(state.copyWith(selectedGenre: genre, clearGenre: genre == null));

  Future<void> loadMore() async {
    if (state.loadingMore ||
        !state.hasMore ||
        state.status != BrowseStatus.success ||
        state.query.isNotEmpty) {
      return;
    }
    emit(state.copyWith(loadingMore: true));
    await _fetch(reset: false);
  }

  Future<void> _fetch({required bool reset}) async {
    final skip = reset ? 0 : state.skip;
    final isSearch = state.query.isNotEmpty;
    final types = state.category.types;

    final responses = await Future.wait(
      types.map((type) {
        return isSearch
            ? _search(SearchParams(type: type, query: state.query))
            : _getCatalog(CatalogParams(type: type, skip: skip));
      }),
    );

    // Total failure — keep what we have, surface error only on a fresh load.
    if (responses.every((r) => r.isLeft())) {
      final key = responses.first.fold((f) => f.message, (_) => null);
      if (reset) {
        emit(state.copyWith(status: BrowseStatus.failure, errorKey: key));
      } else {
        emit(state.copyWith(loadingMore: false, hasMore: false));
      }
      return;
    }

    // Largest single-type batch advances the shared skip offset.
    var step = 0;
    final fetched = <CatalogItem>[];
    for (final r in responses) {
      final list = r.getOrElse(() => const <CatalogItem>[]);
      if (list.length > step) step = list.length;
      fetched.addAll(list);
    }

    final base = reset ? <CatalogItem>[] : state.items;
    final seen = base.map((i) => i.id).toSet();
    final added = [
      for (final item in fetched)
        if (item.id.isNotEmpty && seen.add(item.id)) item,
    ];
    final merged = [...base, ...added];

    emit(
      state.copyWith(
        status: BrowseStatus.success,
        items: merged,
        skip: skip + (step == 0 ? merged.length : step),
        // Stop paginating on search, on an empty page, or when nothing new came.
        hasMore: !isSearch && step > 0 && added.isNotEmpty,
        loadingMore: false,
        clearError: true,
      ),
    );
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
