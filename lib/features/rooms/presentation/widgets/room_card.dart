import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/logic/favorites/favorites_cubit.dart';
import '/logic/favorites/favorites_state.dart';
import '../../domain/entities/room.dart';
import 'room_thumbnail.dart';

/// A single room tile in the home grid: thumbnail, name, live viewer badge and
/// password/embed markers.
class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.room, required this.onTap});

  final Room room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RoomThumbnail(room: room),
                  Positioned(top: 8, left: 8, child: _viewerBadge(context)),
                  Positioned(bottom: 8, left: 8, child: _FavoriteStar(slug: room.slug)),
                  if (room.hasPassword)
                    const Positioned(top: 8, right: 8, child: _Marker(icon: Icons.lock_rounded)),
                  if (room.isExternal)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _Chip(label: context.tr(TranslationKeys.externalBadge)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    room.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    room.viewCountLabel ?? '',
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _viewerBadge(BuildContext context) {
    final live = room.viewerCount > 0;
    final color = live ? context.semantic.success : Colors.black.withValues(alpha: 0.55);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: live ? color.withValues(alpha: 0.9) : color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            live ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            live
                ? '${room.viewerCount} ${context.tr(TranslationKeys.watching)}'
                : context.tr(TranslationKeys.noOneWatching),
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// A tappable star overlay that stars / un-stars the room. Lives on top of the
/// card's [InkWell], so tapping it toggles the favorite without opening the room.
class _FavoriteStar extends StatelessWidget {
  const _FavoriteStar({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FavoritesCubit, FavoritesState>(
      buildWhen: (a, b) =>
          a.favorites.contains(slug) != b.favorites.contains(slug),
      builder: (context, state) {
        final fav = state.favorites.contains(slug);
        return Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.read<FavoritesCubit>().toggle(slug),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                fav ? Icons.star_rounded : Icons.star_outline_rounded,
                size: 16,
                color: fav ? Colors.amber : Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 14, color: Colors.white),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.colors.onPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
