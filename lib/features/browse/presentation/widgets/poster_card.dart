import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/features/favorites/presentation/bloc/catalog_favorites_cubit.dart';
import '/features/favorites/presentation/bloc/catalog_favorites_state.dart';
import '../../domain/entities/catalog_item.dart';
import 'source_badge.dart';

/// A single poster tile in the Browse grid: cached poster image, an IMDB rating
/// badge, and the title + year beneath it.
class PosterCard extends StatelessWidget {
  const PosterCard({super.key, required this.item, required this.onTap});

  final CatalogItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _poster(context),
                  if (item.imdbRating != null)
                    Positioned(top: 8, right: 8, child: _ratingBadge(context)),
                  Positioned(top: 4, left: 4, child: _FavoriteHeart(item: item)),
                  Positioned(bottom: 6, left: 6, child: SourceBadge(source: item.source)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                  if (item.releaseInfo != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.releaseInfo!,
                      style: context.text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _poster(BuildContext context) {
    final placeholder = Container(
      color: context.colors.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        item.isSeries ? Icons.live_tv_rounded : Icons.movie_rounded,
        color: context.colors.onSurfaceVariant.withValues(alpha: 0.4),
        size: 36,
      ),
    );
    final url = item.poster;
    if (url == null) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => placeholder,
      errorWidget: (_, _, _) => placeholder,
    );
  }

  Widget _ratingBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
          const SizedBox(width: 3),
          Text(
            item.imdbRating!,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Heart overlay on a poster that saves / removes the title from the global
/// server favorites. Reads the app-wide [CatalogFavoritesCubit] directly so it
/// works in both the Browse grid and the Favorites tab without extra wiring.
class _FavoriteHeart extends StatelessWidget {
  const _FavoriteHeart({required this.item});

  final CatalogItem item;

  Future<void> _toggle(BuildContext context) async {
    try {
      await context.read<CatalogFavoritesCubit>().toggle(item);
    } catch (_) {
      if (context.mounted) {
        context.showSnack(context.tr(TranslationKeys.errorRequestFailed));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CatalogFavoritesCubit, CatalogFavoritesState>(
      buildWhen: (a, b) => a.isFavorite(item.id) != b.isFavorite(item.id),
      builder: (context, state) {
        final isFav = state.isFavorite(item.id);
        return Material(
          type: MaterialType.transparency,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _toggle(context),
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18,
                color: isFav ? Colors.redAccent : Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}
