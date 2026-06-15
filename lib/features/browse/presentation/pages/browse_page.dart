import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/status_view.dart';
import '/injections/injection.dart';
import '/routes/routes_names.dart';
import '../../domain/entities/browse_category.dart';
import '../../domain/entities/catalog_item.dart';
import '../bloc/browse/browse_cubit.dart';
import '../bloc/browse/browse_state.dart';
import '../widgets/browse_shimmer.dart';
import '../widgets/poster_card.dart';

/// Catalogue tab: browse / search movies and series, filter by genre, and open
/// a title's detail page. Fetches from Cinemeta via [BrowseCubit].
class BrowsePage extends StatelessWidget {
  const BrowsePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BrowseCubit>(
      create: (_) => sl<BrowseCubit>()..load(),
      child: const _BrowseView(),
    );
  }
}

class _BrowseView extends StatelessWidget {
  const _BrowseView();

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
            child: BlocBuilder<BrowseCubit, BrowseState>(
              builder: (context, state) {
                return switch (state.status) {
                  BrowseStatus.initial || BrowseStatus.loading => const BrowseShimmer(),
                  BrowseStatus.failure => StatusView(
                    icon: Icons.cloud_off_rounded,
                    title: context.tr(TranslationKeys.errorUnknown),
                    message: context.tr(state.errorKey ?? TranslationKeys.errorUnknown),
                    actionLabel: context.tr(TranslationKeys.retry),
                    onAction: () => context.read<BrowseCubit>().load(),
                  ),
                  BrowseStatus.success => _grid(context, state),
                };
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final cubit = context.read<BrowseCubit>();
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
      child: BlocBuilder<BrowseCubit, BrowseState>(
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
                  context.read<BrowseCubit>().setCategory(s.first),
              showSelectedIcon: false,
            ),
          );
        },
      ),
    );
  }

  Widget _genreChips(BuildContext context) {
    return BlocBuilder<BrowseCubit, BrowseState>(
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
                onSelected: (_) => context.read<BrowseCubit>().setGenre(null),
              ),
              for (final genre in genres) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(genre),
                  selected: state.selectedGenre == genre,
                  onSelected: (sel) =>
                      context.read<BrowseCubit>().setGenre(sel ? genre : null),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _grid(BuildContext context, BrowseState state) {
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
      controller: context.read<BrowseCubit>().scrollController,
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
              return PosterCard(
                item: item,
                onTap: () => _openDetail(context, item),
              );
            },
          ),
        ),
        // A footer that auto-loads on scroll, but is also a tappable button so
        // a short page (e.g. only a couple of results) can still fetch more
        // without anything to scroll.
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
                        onPressed: () => context.read<BrowseCubit>().loadMore(),
                        icon: const Icon(Icons.expand_more_rounded),
                        label: Text(context.tr(TranslationKeys.loadMore)),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  void _openDetail(BuildContext context, CatalogItem item) {
    context.pushNamed(
      RoutesNames.browseDetail,
      pathParameters: {'type': item.type, 'id': item.id},
      extra: item,
    );
  }
}
