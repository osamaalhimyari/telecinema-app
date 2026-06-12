import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '/features/browse/domain/entities/catalog_item.dart';
import '/features/browse/presentation/pages/browse_page.dart';
import '/features/browse/presentation/pages/detail_page.dart';
import '/features/cache/presentation/pages/cached_videos_page.dart';
import '/features/favorites/presentation/pages/favorites_page.dart';
import '/features/shell/main_shell.dart';
import '../features/rooms/domain/entities/room.dart';
import '../features/rooms/presentation/pages/create_room_page.dart';
import '../features/rooms/presentation/pages/rooms_page.dart';
import '../features/subtitles/presentation/pages/subtitles_page.dart';
import '../features/watch/presentation/pages/room_page.dart';
import 'routes_names.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Single [GoRouter] for the app. The three tabs (Rooms / Browse / Favorites)
/// live inside a [StatefulShellRoute] under [MainShell]; create-room, the player
/// and title details are pushed on the root navigator, above the bottom bar.
/// No auth gate — every room is public, and password rooms use an in-page
/// unlock overlay.
final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, navigationShell) =>
          MainShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: RoutesNames.rooms,
              path: '/',
              builder: (_, _) => const RoomsPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: RoutesNames.browse,
              path: '/browse',
              builder: (_, _) => const BrowsePage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              name: RoutesNames.favorites,
              path: '/favorites',
              builder: (_, _) => const FavoritesPage(),
            ),
          ],
        ),
      ],
    ),

    // ----- Full-screen routes (root navigator, above the shell) -----
    GoRoute(
      name: RoutesNames.createRoom,
      path: '/create',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) {
        final extra = state.extra;
        final prefill = extra is Map ? extra : const {};
        return CreateRoomPage(
          initialName: prefill['name'] as String?,
          initialMagnet: prefill['magnet'] as String?,
          initialVideoUrl: prefill['videoUrl'] as String?,
          initialCategory: prefill['category'] as String?,
          initialImdbId: prefill['imdbId'] as String?,
        );
      },
    ),
    GoRoute(
      name: RoutesNames.room,
      path: '/room/:slug',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) => RoomPage(
        slug: state.pathParameters['slug'] ?? '',
        initialRoom: state.extra is Room ? state.extra as Room : null,
      ),
    ),
    GoRoute(
      name: RoutesNames.cached,
      path: '/cached',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, _) => const CachedVideosPage(),
    ),
    GoRoute(
      name: RoutesNames.subtitles,
      path: '/room/:slug/subtitles',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) {
        final extra = state.extra is Map ? state.extra as Map : const {};
        return SubtitlesPage(
          slug: state.pathParameters['slug'] ?? '',
          imdbId: extra['imdbId'] as String?,
          title: extra['title'] as String?,
          release: extra['release'] as String?,
          magnet: extra['magnet'] as String?,
        );
      },
    ),
    GoRoute(
      name: RoutesNames.browseDetail,
      path: '/title/:type/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (_, state) => DetailPage(
        type: state.pathParameters['type'] ?? 'movie',
        id: state.pathParameters['id'] ?? '',
        initial: state.extra is CatalogItem ? state.extra as CatalogItem : null,
      ),
    ),
  ],
);
