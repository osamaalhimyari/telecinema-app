import 'package:go_router/go_router.dart';

import '/features/rooms/domain/entities/room.dart';
import '/features/rooms/presentation/pages/create_room_page.dart';
import '/features/rooms/presentation/pages/rooms_page.dart';
import '/features/watch/presentation/pages/room_page.dart';
import 'routes_names.dart';

/// Single [GoRouter] for the app. No auth gate — every room is public, and
/// password-protected rooms are handled by an in-page unlock overlay.
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      name: RoutesNames.rooms,
      path: '/',
      builder: (_, _) => const RoomsPage(),
      routes: [
        GoRoute(
          name: RoutesNames.createRoom,
          path: 'create',
          builder: (_, _) => const CreateRoomPage(),
        ),
        GoRoute(
          name: RoutesNames.room,
          path: 'room/:slug',
          builder: (_, state) => RoomPage(
            slug: state.pathParameters['slug'] ?? '',
            initialRoom: state.extra is Room ? state.extra as Room : null,
          ),
        ),
      ],
    ),
  ],
);
