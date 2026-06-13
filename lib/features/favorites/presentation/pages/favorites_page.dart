import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/status_view.dart';
import '/features/cinema/domain/entities/cinema_item.dart';
import '/routes/routes_names.dart';
import '../../../browse/domain/entities/catalog_item.dart';
import '../../../browse/presentation/widgets/browse_shimmer.dart';
import '../../../browse/presentation/widgets/poster_card.dart';
import '../bloc/catalog_favorites_cubit.dart';
import '../bloc/catalog_favorites_state.dart';
import '../bloc/favorites_filter/favorites_filter_cubit.dart';
import '../bloc/favorites_filter/favorites_filter_state.dart';

/// Favorites tab: the account-less global list of movies/series saved from the
/// catalogues. Reuses the same [PosterCard] tiles, and opens the right detail
/// page per title — the IMDB/Browse page for Cinemeta titles, the Cinema page
/// for EgyBest titles — using each favorite's `source`. When both catalogues are
/// present a small filter lets the user view them separately.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FavoritesFilterCubit(),
      child: const _FavoritesView(),
    );
  }
}

class _FavoritesView extends StatelessWidget {
  const _FavoritesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(TranslationKeys.favoritesTitle))),
      body: BlocBuilder<CatalogFavoritesCubit, CatalogFavoritesState>(
        builder: (context, state) {
          // Only show the shimmer on the very first load — a pull-to-refresh
          // keeps the current grid visible behind the refresh spinner.
          return switch (state.status) {
            CatalogFavoritesStatus.initial => const BrowseShimmer(),
            CatalogFavoritesStatus.loading when state.items.isEmpty =>
              const BrowseShimmer(),
            CatalogFavoritesStatus.failure when state.items.isEmpty => StatusView(
              icon: Icons.cloud_off_rounded,
              title: context.tr(TranslationKeys.errorUnknown),
              message: context.tr(state.errorKey ?? TranslationKeys.errorUnknown),
              actionLabel: context.tr(TranslationKeys.retry),
              onAction: () => context.read<CatalogFavoritesCubit>().load(),
            ),
            _ => _body(context, state),
          };
        },
      ),
    );
  }

  Widget _body(BuildContext context, CatalogFavoritesState state) {
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => context.read<CatalogFavoritesCubit>().load(),
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
            StatusView(
              icon: Icons.favorite_border_rounded,
              title: context.tr(TranslationKeys.favoritesEmpty),
              message: context.tr(TranslationKeys.favoritesEmptyHint),
            ),
          ],
        ),
      );
    }

    // Both catalogues present → offer a filter so they can be viewed separately.
    final hasEgybest = state.items.any((i) => i.isEgybest);
    final hasCinemeta = state.items.any((i) => !i.isEgybest);
    final showFilter = hasEgybest && hasCinemeta;

    return BlocBuilder<FavoritesFilterCubit, FavoritesFilterState>(
      builder: (context, filter) {
        final items = filter.source == null
            ? state.items
            : state.items.where((i) => i.source == filter.source).toList();

        return Column(
          children: [
            if (showFilter) _filter(context, filter.source),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => context.read<CatalogFavoritesCubit>().load(),
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
            ),
          ],
        );
      },
    );
  }

  Widget _filter(BuildContext context, String? source) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String?>(
          segments: [
            ButtonSegment(value: null, label: Text(context.tr(TranslationKeys.categoryAll))),
            ButtonSegment(
              value: 'cinemeta',
              label: Text(context.tr(TranslationKeys.favoritesSourceImdb)),
            ),
            ButtonSegment(
              value: 'egybest',
              label: Text(context.tr(TranslationKeys.favoritesSourceCinema)),
            ),
          ],
          selected: {source},
          onSelectionChanged: (s) => context.read<FavoritesFilterCubit>().select(s.first),
          showSelectedIcon: false,
        ),
      ),
    );
  }

  /// EgyBest favorites open the Cinema detail page; everything else (legacy +
  /// Cinemeta) opens the Browse/IMDB detail page — keeping the two flows fully
  /// separate.
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
