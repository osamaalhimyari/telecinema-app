import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';

/// App shell hosting the persistent bottom-nav tabs (Rooms / Browse /
/// Favorites). Browse is the unified IMDB + Cinema catalogue. Each tab keeps its
/// own navigation state via [StatefulNavigationShell]; full-screen routes
/// (create room, the player, title details) are pushed above this shell.
/// Destination order must match the shell branch order in [router].
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    // Tapping the active tab pops it back to its initial route.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.meeting_room_outlined),
            selectedIcon: const Icon(Icons.meeting_room_rounded),
            label: context.tr(TranslationKeys.roomsTab),
          ),
          //  NavigationDestination(
          //   icon: const Icon(Icons.play_circle_outline_rounded),
          //   selectedIcon: const Icon(Icons.play_circle_rounded),
          //   label: context.tr(TranslationKeys.youtubeTab),
          // ),
          // Browse — unified IMDB + Cinema catalogue (one tab, branch index 1).
          NavigationDestination(
            icon: const Icon(Icons.movie_outlined),
            selectedIcon: const Icon(Icons.movie_rounded),
            label: context.tr(TranslationKeys.browseTab),
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline_rounded),
            selectedIcon: const Icon(Icons.favorite_rounded),
            label: context.tr(TranslationKeys.favoritesTab),
          ),
        ],
      ),
    );
  }
}
