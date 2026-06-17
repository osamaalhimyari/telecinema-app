import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/status_view.dart';
import '/features/browse/domain/entities/browse_category.dart';
import '/features/browse/domain/entities/browse_sort.dart';
import '/features/browse/domain/entities/catalog_item.dart';
import '/features/browse/presentation/widgets/browse_shimmer.dart';
import '/features/browse/presentation/widgets/poster_card.dart';
import '/features/cinema/domain/entities/cinema_item.dart';
import '/injections/injection.dart';
import '/routes/routes_names.dart';
import '../bloc/discover_cubit.dart';
import '../bloc/discover_state.dart';

/// The unified Browse tab: one grid merging the Cinemeta (IMDB) and EgyBest
/// (Cinema) catalogues. Search and scroll pull from both; each card shows its
/// source badge and opens the matching detail page. Reuses Browse's
/// [PosterCard] / shimmer so it looks identical to the old single-source grids.
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DiscoverCubit>(
      create: (_) => sl<DiscoverCubit>()..load(),
      child: const _DiscoverView(),
    );
  }
}

class _DiscoverView extends StatelessWidget {
  const _DiscoverView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(TranslationKeys.browseTitle))),
      body: Column(
        children: [
          _searchField(context),
          _categorySelector(context),
          _genreChips(context),
          _sortRow(context),
          Expanded(
            child: BlocBuilder<DiscoverCubit, DiscoverState>(
              builder: (context, state) {
                return switch (state.status) {
                  DiscoverStatus.initial || DiscoverStatus.loading => const BrowseShimmer(),
                  DiscoverStatus.failure => StatusView(
                    icon: Icons.cloud_off_rounded,
                    title: context.tr(TranslationKeys.errorUnknown),
                    message: context.tr(state.errorKey ?? TranslationKeys.errorUnknown),
                    actionLabel: context.tr(TranslationKeys.retry),
                    onAction: () => context.read<DiscoverCubit>().load(),
                  ),
                  DiscoverStatus.success => _grid(context, state),
                };
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final cubit = context.read<DiscoverCubit>();
    final controller = cubit.searchController;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final hasText = value.text.isNotEmpty;
          return TextField(
            controller: controller,
            textInputAction: TextInputAction.search,
            onChanged: cubit.setQuery,
            decoration: InputDecoration(
              isDense: true,
              hintText: context.tr(TranslationKeys.browseSearchHint),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: hasText
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: cubit.clearSearch,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _categorySelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: BlocBuilder<DiscoverCubit, DiscoverState>(
        buildWhen: (a, b) => a.category != b.category,
        builder: (context, state) {
          return SizedBox(
            width: double.infinity,
            child: SegmentedButton<BrowseCategory>(
              segments: [
                ButtonSegment(
                  value: BrowseCategory.all,
                  label: Text(context.tr(TranslationKeys.categoryAll)),
                ),
                ButtonSegment(
                  value: BrowseCategory.movies,
                  icon: const Icon(Icons.movie_outlined, size: 18),
                  label: Text(context.tr(TranslationKeys.categoryMovies)),
                ),
                ButtonSegment(
                  value: BrowseCategory.series,
                  icon: const Icon(Icons.live_tv_outlined, size: 18),
                  label: Text(context.tr(TranslationKeys.categorySeries)),
                ),
              ],
              selected: {state.category},
              onSelectionChanged: (s) =>
                  context.read<DiscoverCubit>().setCategory(s.first),
              showSelectedIcon: false,
            ),
          );
        },
      ),
    );
  }

  Widget _genreChips(BuildContext context) {
    return BlocBuilder<DiscoverCubit, DiscoverState>(
      buildWhen: (a, b) =>
          a.genres != b.genres || a.selectedGenre != b.selectedGenre,
      builder: (context, state) {
        final genres = state.genres;
        if (genres.isEmpty) return const SizedBox(height: 4);
        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              ChoiceChip(
                label: Text(context.tr(TranslationKeys.allGenres)),
                selected: state.selectedGenre == null,
                onSelected: (_) => context.read<DiscoverCubit>().setGenre(null),
              ),
              for (final genre in genres) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(genre),
                  selected: state.selectedGenre == genre,
                  onSelected: (sel) =>
                      context.read<DiscoverCubit>().setGenre(sel ? genre : null),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Sort selector: a row of chips that reorder the loaded titles locally
  /// (catalogue order / release date / rating). Mirrors the genre chips' style.
  Widget _sortRow(BuildContext context) {
    return BlocBuilder<DiscoverCubit, DiscoverState>(
      buildWhen: (a, b) => a.sort != b.sort,
      builder: (context, state) {
        return SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            children: [
              for (final sort in BrowseSort.values) ...[
                ChoiceChip(
                  avatar: Icon(_sortIcon(sort), size: 16),
                  label: Text(context.tr(_sortLabel(sort))),
                  selected: state.sort == sort,
                  onSelected: (_) => context.read<DiscoverCubit>().setSort(sort),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  IconData _sortIcon(BrowseSort sort) => switch (sort) {
    BrowseSort.defaultOrder => Icons.sort_rounded,
    BrowseSort.releaseDate => Icons.calendar_today_rounded,
    BrowseSort.rating => Icons.star_rounded,
  };

  String _sortLabel(BrowseSort sort) => switch (sort) {
    BrowseSort.defaultOrder => TranslationKeys.browseSortDefault,
    BrowseSort.releaseDate => TranslationKeys.browseSortRelease,
    BrowseSort.rating => TranslationKeys.browseSortRating,
  };

  Widget _grid(BuildContext context, DiscoverState state) {
    final items = state.visibleItems;
    if (items.isEmpty) {
      return StatusView(
        icon: Icons.search_off_rounded,
        title: context.tr(TranslationKeys.browseNoResults),
        message: context.tr(TranslationKeys.browseNoResultsHint),
      );
    }
    // Paginating is only possible on the unfiltered catalogue, not a search.
    final canLoadMore = state.query.isEmpty && state.hasMore;
    return CustomScrollView(
      controller: context.read<DiscoverCubit>().scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 0.58,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return PosterCard(item: item, onTap: () => _openDetail(context, item));
            },
          ),
        ),
        // An explicit "Load more" button (no auto-load on scroll) — the user
        // controls when the next page is fetched.
        if (canLoadMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Center(
                child: state.loadingMore
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => context.read<DiscoverCubit>().loadMore(),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: Text(context.tr(TranslationKeys.loadMore)),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  /// EgyBest cards open the Cinema detail page; Cinemeta cards open the IMDB
  /// detail page — same split the Favorites tab uses.
  void _openDetail(BuildContext context, CatalogItem item) {
    if (item.isEgybest) {
      context.pushNamed(
        RoutesNames.cinemaDetail,
        pathParameters: {'type': item.type, 'id': item.id},
        extra: CinemaItem.fromCatalogItem(item),
      );
    } else {
      context.pushNamed(
        RoutesNames.browseDetail,
        pathParameters: {'type': item.type, 'id': item.id},
        extra: item,
      );
    }
  }
}
