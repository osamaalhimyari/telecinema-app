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
      child: Row(
        children: [
          Expanded(
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
          ),
          const SizedBox(width: 8),
          // Compact sort control beside the search to save a whole row; its menu
          // holds the sort field plus ascending/descending.
          _sortButton(context),
        ],
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

  /// Compact sort control beside the search box. Its dropdown lists the sort
  /// field (Default / Release date / Rating) and, below a divider, the direction
  /// (Descending / Ascending) — disabled for Default, which has no direction.
  /// The button itself shows a sort icon plus an up/down arrow for the direction.
  Widget _sortButton(BuildContext context) {
    return BlocBuilder<DiscoverCubit, DiscoverState>(
      buildWhen: (a, b) => a.sort != b.sort || a.sortAscending != b.sortAscending,
      builder: (context, state) {
        final cubit = context.read<DiscoverCubit>();
        final isDefault = state.sort == BrowseSort.defaultOrder;
        return PopupMenuButton<String>(
          tooltip: context.tr(TranslationKeys.browseSort),
          position: PopupMenuPosition.under,
          onSelected: (value) {
            switch (value) {
              case 'default':
                cubit.setSort(BrowseSort.defaultOrder);
              case 'release':
                cubit.setSort(BrowseSort.releaseDate);
              case 'rating':
                cubit.setSort(BrowseSort.rating);
              case 'desc':
                cubit.setSortAscending(false);
              case 'asc':
                cubit.setSortAscending(true);
            }
          },
          itemBuilder: (context) => [
            CheckedPopupMenuItem(
              value: 'default',
              checked: state.sort == BrowseSort.defaultOrder,
              child: Text(context.tr(TranslationKeys.browseSortDefault)),
            ),
            CheckedPopupMenuItem(
              value: 'release',
              checked: state.sort == BrowseSort.releaseDate,
              child: Text(context.tr(TranslationKeys.browseSortRelease)),
            ),
            CheckedPopupMenuItem(
              value: 'rating',
              checked: state.sort == BrowseSort.rating,
              child: Text(context.tr(TranslationKeys.browseSortRating)),
            ),
            const PopupMenuDivider(),
            CheckedPopupMenuItem(
              value: 'desc',
              enabled: !isDefault,
              checked: !state.sortAscending,
              child: Text(context.tr(TranslationKeys.browseSortDescending)),
            ),
            CheckedPopupMenuItem(
              value: 'asc',
              enabled: !isDefault,
              checked: state.sortAscending,
              child: Text(context.tr(TranslationKeys.browseSortAscending)),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort_rounded, size: 20),
                if (!isDefault) ...[
                  const SizedBox(width: 2),
                  Icon(
                    state.sortAscending
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 15,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

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
