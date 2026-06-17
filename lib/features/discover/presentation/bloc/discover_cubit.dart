import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/services/locale_service.dart';
import '/features/browse/domain/entities/browse_category.dart';
import '/features/browse/domain/entities/browse_sort.dart';
import '/features/browse/domain/entities/catalog_item.dart';
import '/features/browse/domain/usecases/get_catalog_usecase.dart';
import '/features/browse/domain/usecases/get_meta_detail_usecase.dart';
import '/features/browse/domain/usecases/search_catalog_usecase.dart';
import '/features/cinema/data/datasources/cinema_remote_datasource.dart';
import '/features/cinema/domain/entities/cinema_item.dart';
import '../../data/genre_map.dart';
import 'discover_state.dart';

/// Drives the unified Browse grid — one feed that fans out to BOTH the Cinemeta
/// (IMDB) catalogue and the EgyBest (Cinema) catalogue, merges and shuffles the
/// results, paginates each source independently, and searches both at once. Each
/// card keeps its `source`, so a tap opens the right detail page and the badge
/// shows the right logo.
///
/// Cinemeta ships lean metas that often omit `imdbRating` (even for famous
/// titles, especially in search). This cubit backfills those ratings in the
/// background so the IMDB cards show them consistently.
class DiscoverCubit extends Cubit<DiscoverState> {
  DiscoverCubit(
    this._getCatalog,
    this._search,
    this._getMetaDetail,
    this._cinema,
    this._locale,
  ) : super(const DiscoverState());

  final GetCatalogUseCase _getCatalog;
  final SearchCatalogUseCase _search;
  final GetMetaDetailUseCase _getMetaDetail;
  final CinemaRemoteDataSource _cinema;
  final LocaleService _locale;

  /// Owned by the cubit so they survive widget rebuilds; disposed in [close].
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  Timer? _debounce;
  final Map<String, String> _ratingCache = {};
  final Set<String> _ratingPending = {};

  Future<void> load() async {
    emit(
      state.copyWith(
        status: DiscoverStatus.loading,
        items: const [],
        cinemetaSkip: 0,
        cinemaPage: 1,
        cinemetaHasMore: true,
        cinemaHasMore: true,
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

  void setQuery(String raw) {
    final query = raw.trim();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (query == state.query) return;
      emit(state.copyWith(query: query));
      load();
    });
  }

  void setGenre(String? genre) =>
      emit(state.copyWith(selectedGenre: genre, clearGenre: genre == null));

  /// Local-only ordering of the loaded items — no refetch.
  void setSort(BrowseSort sort) {
    if (sort == state.sort) return;
    emit(state.copyWith(sort: sort));
  }

  /// Clears the search field text and resets the query (the x button).
  void clearSearch() {
    searchController.clear();
    setQuery('');
  }

  Future<void> loadMore() async {
    if (state.loadingMore ||
        !state.hasMore ||
        state.status != DiscoverStatus.success ||
        state.query.isNotEmpty) {
      return;
    }
    emit(state.copyWith(loadingMore: true));
    await _fetch(reset: false);
  }

  Future<void> _fetch({required bool reset}) async {
    final skip = reset ? 0 : state.cinemetaSkip;
    final page = reset ? 1 : state.cinemaPage;
    final isSearch = state.query.isNotEmpty;

    // Fan out to both catalogues concurrently.
    final cmFuture = _fetchCinemeta(isSearch, skip);
    final cineFuture = _fetchCinema(isSearch, page);
    final cm = await cmFuture;
    final cine = await cineFuture;

    // Both failed — surface an error only on a fresh load.
    if (!cm.ok && !cine.ok) {
      if (reset) {
        emit(state.copyWith(status: DiscoverStatus.failure, errorKey: cm.errorKey ?? 'error_unknown'));
      } else {
        emit(state.copyWith(loadingMore: false, cinemetaHasMore: false, cinemaHasMore: false));
      }
      return;
    }

    // Mix the two sources so the grid shows random cards from both.
    final fetched = [...cm.items, ...cine.items]..shuffle();

    final base = reset ? <CatalogItem>[] : state.items;
    final seen = base.map(_key).toSet();
    final added = [
      for (final item in fetched)
        if (item.id.isNotEmpty && seen.add(_key(item))) _normalizeGenres(item),
    ];
    final merged = [...base, ...added];

    emit(
      state.copyWith(
        status: DiscoverStatus.success,
        items: merged,
        cinemetaSkip: skip + (cm.step == 0 ? cm.items.length : cm.step),
        cinemaPage: page + 1,
        cinemetaHasMore: !isSearch && cm.step > 0,
        cinemaHasMore: !isSearch && cine.hasMore,
        loadingMore: false,
        clearError: true,
      ),
    );

    unawaited(_backfillRatings(added));
  }

  /// `source:id` — Cinemeta ids (`tt…`) and EgyBest ids (numeric) never collide,
  /// but keying on both keeps it correct regardless.
  String _key(CatalogItem i) => '${i.source}:${i.id}';

  /// Rewrites an item's genres to one canonical, localized set so the chips
  /// aren't a mix of English (Cinemeta) and Arabic (EgyBest) — `Action` / `حركة`
  /// collapse to a single chip in the app's language.
  CatalogItem _normalizeGenres(CatalogItem i) {
    final genres = GenreMap.localizeAll(i.genres, _locale.locale.languageCode);
    return CatalogItem(
      id: i.id,
      name: i.name,
      type: i.type,
      poster: i.poster,
      imdbRating: i.imdbRating,
      releaseInfo: i.releaseInfo,
      genres: genres,
      source: i.source,
    );
  }

  // ----- per-source fetch -----

  Future<({List<CatalogItem> items, int step, bool ok, String? errorKey})> _fetchCinemeta(
    bool isSearch,
    int skip,
  ) async {
    final types = state.category.types;
    final results = await Future.wait(
      types.map((t) => isSearch
          ? _search(SearchParams(type: t, query: state.query))
          : _getCatalog(CatalogParams(type: t, skip: skip))),
    );
    var ok = false;
    var step = 0;
    String? errorKey;
    final items = <CatalogItem>[];
    for (final r in results) {
      r.fold(
        (f) => errorKey ??= f.message,
        (list) {
          ok = true;
          if (list.length > step) step = list.length;
          items.addAll(list);
        },
      );
    }
    return (items: items, step: step, ok: ok, errorKey: errorKey);
  }

  Future<({List<CatalogItem> items, bool hasMore, bool ok})> _fetchCinema(
    bool isSearch,
    int page,
  ) async {
    try {
      if (isSearch) {
        final r = await _cinema.search(state.query);
        return (
          // EgyBest search also returns `anime` (the listings don't); drop it —
          // only movie/series have a detail page, so an anime card couldn't open.
          items: r
              .where((e) => e.type != 'anime')
              .where(_matchesCategory)
              .map((e) => e.toCatalogItem())
              .toList(),
          hasMore: false,
          ok: true,
        );
      }
      final results = await Future.wait(
        _cinemaListings().map((l) => _cinema.catalog(listing: l, page: page)),
      );
      final items = <CatalogItem>[];
      var hasMore = false;
      for (final res in results) {
        items.addAll(res.items.map((e) => e.toCatalogItem()));
        if (res.hasMore) hasMore = true;
      }
      return (items: items, hasMore: hasMore, ok: true);
    } catch (_) {
      return (items: const <CatalogItem>[], hasMore: false, ok: false);
    }
  }

  List<String> _cinemaListings() => switch (state.category) {
    BrowseCategory.all => const ['movies', 'series'],
    BrowseCategory.movies => const ['movies'],
    BrowseCategory.series => const ['series'],
  };

  bool _matchesCategory(CinemaItem item) => switch (state.category) {
    BrowseCategory.all => true,
    BrowseCategory.movies => !item.isSeries,
    BrowseCategory.series => item.isSeries,
  };

  // ----- rating backfill -----

  /// Fills missing IMDB ratings for the freshly-added Cinemeta cards by fetching
  /// each title's meta in capped-concurrency batches, caching results, and
  /// emitting progressive updates. EgyBest cards already carry a rating.
  Future<void> _backfillRatings(List<CatalogItem> added) async {
    final todo = added
        .where((i) =>
            i.source != 'egybest' &&
            i.imdbRating == null &&
            i.id.isNotEmpty &&
            !_ratingPending.contains(i.id))
        .toList();
    if (todo.isEmpty) return;
    for (final i in todo) {
      _ratingPending.add(i.id);
    }

    const cap = 6;
    for (var s = 0; s < todo.length; s += cap) {
      if (isClosed) return;
      final batch = todo.skip(s).take(cap).toList();
      final results = await Future.wait(batch.map(_fetchRating));
      final found = <String, String>{
        for (final e in results)
          if (e.value != null) e.key: e.value!,
      };
      if (found.isNotEmpty && !isClosed) {
        emit(state.copyWith(items: _applyRatings(state.items, found)));
      }
    }
  }

  Future<MapEntry<String, String?>> _fetchRating(CatalogItem item) async {
    final cached = _ratingCache[item.id];
    if (cached != null) return MapEntry(item.id, cached);
    final res = await _getMetaDetail(DetailParams(type: item.type, id: item.id));
    final rating = res.fold((_) => null, (m) => m.imdbRating);
    if (rating != null) _ratingCache[item.id] = rating;
    return MapEntry(item.id, rating);
  }

  List<CatalogItem> _applyRatings(List<CatalogItem> items, Map<String, String> ratings) {
    return items.map((it) {
      final r = ratings[it.id];
      if (r == null || it.source == 'egybest' || it.imdbRating != null) return it;
      return CatalogItem(
        id: it.id,
        name: it.name,
        type: it.type,
        poster: it.poster,
        imdbRating: r,
        releaseInfo: it.releaseInfo,
        genres: it.genres,
        source: it.source,
      );
    }).toList();
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    scrollController.dispose();
    searchController.dispose();
    return super.close();
  }
}
