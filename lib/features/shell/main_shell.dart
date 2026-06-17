import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
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

  /// Intercepts the system back gesture at the home shell (where there is
  /// nothing left to pop, so back would close the app). On a secondary tab it
  /// just returns to the first tab; on the first tab it asks before exiting.
  Future<void> _onPop(BuildContext context, bool didPop) async {
    if (didPop) return;
    if (navigationShell.currentIndex != 0) {
      navigationShell.goBranch(0, initialLocation: true);
      return;
    }
    final exit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr(TranslationKeys.exitAppTitle)),
        content: Text(ctx.tr(TranslationKeys.exitAppMessage)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.tr(TranslationKeys.cancel)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.tr(TranslationKeys.exitApp)),
          ),
        ],
      ),
    );
    if (exit ?? false) await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Always intercept: we decide in [_onPop] whether to switch tabs or
      // confirm exiting, so the shell never pops straight out of the app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPop(context, didPop),
      child: Scaffold(
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
      ),
    );
  }
}
