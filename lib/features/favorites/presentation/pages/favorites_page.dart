import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/status_view.dart';
import '/routes/routes_names.dart';
import '../../../browse/domain/entities/catalog_item.dart';
import '../../../browse/presentation/widgets/browse_shimmer.dart';
import '../../../browse/presentation/widgets/poster_card.dart';
import '../bloc/catalog_favorites_cubit.dart';
import '../bloc/catalog_favorites_state.dart';

/// Favorites tab: the account-less global list of movies/series saved from the
/// catalogue. Reuses the same [PosterCard] tiles and opens the same detail page
/// as Browse, so a saved title behaves exactly like a browsed one.
class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

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
    return RefreshIndicator(
      onRefresh: () => context.read<CatalogFavoritesCubit>().load(),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.58,
        ),
        itemCount: state.items.length,
        itemBuilder: (context, i) {
          final item = state.items[i];
          return PosterCard(item: item, onTap: () => _openDetail(context, item));
        },
      ),
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
