import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/constants/categories.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/status_view.dart';
import '/injections/injection.dart';
import '/features/app_update/presentation/widgets/update_button.dart';
import '/features/operations/presentation/widgets/operations_button.dart';
import '/features/cache/data/cache_manager.dart';
import '/features/cache/domain/entities/cached_video.dart';
import '/features/tv/presentation/pages/tv_groups_page.dart';
import '/logic/favorites/favorites_cubit.dart';
import '/logic/favorites/favorites_state.dart';
import '/routes/routes_names.dart';
import '../../domain/entities/room.dart';
import '../bloc/rooms_list/rooms_list_cubit.dart';
import '../bloc/rooms_list/rooms_list_state.dart';
import '../bloc/rooms_view/rooms_view_cubit.dart';
import '../bloc/rooms_view/rooms_view_state.dart';
import '../widgets/room_card.dart';
import '../widgets/settings_sheet.dart';

/// Home — the grid of every available room, with live viewer counts.
class RoomsPage extends StatelessWidget {
  const RoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<RoomsListCubit>(
          create: (_) => sl<RoomsListCubit>()..load(),
        ),
        BlocProvider<RoomsViewCubit>(
          create: (_) => RoomsViewCubit(),
        ),
      ],
      child: const _RoomsView(),
    );
  }
}

class _RoomsView extends StatelessWidget {
  const _RoomsView();

  /// Applies the favorites/recent collection on top of the cubit's already
  /// search- and category-filtered [RoomsListState.visibleRooms].
  List<Room> _filtered(
    RoomsListState state,
    FavoritesState favorites,
    RoomsCollection collection,
  ) {
    final rooms = state.visibleRooms;
    switch (collection) {
      case RoomsCollection.all:
        return rooms;
      case RoomsCollection.favorites:
        return rooms.where((r) => favorites.favorites.contains(r.slug)).toList();
      case RoomsCollection.recent:
        final order = {
          for (var i = 0; i < favorites.recents.length; i++) favorites.recents[i]: i,
        };
        return rooms.where((r) => order.containsKey(r.slug)).toList()
          ..sort((a, b) => order[a.slug]!.compareTo(order[b.slug]!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(TranslationKeys.roomsTitle)),
        actions: [
          const UpdateButton(),
          const OperationsButton(),
          // Live TV — browse channels, preview one, then create a watch room.
          IconButton(
            tooltip: context.tr(TranslationKeys.tvTitle),
            icon: const Icon(Icons.live_tv_rounded),
            onPressed: () => Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const TvGroupsPage()),
            ),
          ),
          // Only surfaced once something is cached on this device; hidden while
          // the on-device library is empty.
          StreamBuilder<List<CachedVideo>>(
            stream: sl<CacheManager>().changes,
            initialData: sl<CacheManager>().list(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const <CachedVideo>[];
              if (items.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: context.tr(TranslationKeys.cachedVideos),
                icon: const Icon(Icons.download_for_offline_outlined),
                onPressed: () => context.pushNamed(RoutesNames.cached),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => SettingsSheet.show(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.pushNamed(RoutesNames.createRoom);
          if (context.mounted) context.read<RoomsListCubit>().refresh();
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(context.tr(TranslationKeys.createRoom)),
      ),
      body: BlocBuilder<RoomsListCubit, RoomsListState>(
        builder: (context, state) {
          return switch (state.status) {
            RoomsListStatus.loading || RoomsListStatus.initial =>
              const Center(child: CircularProgressIndicator()),
            RoomsListStatus.failure => StatusView(
              icon: Icons.cloud_off_rounded,
              title: context.tr(TranslationKeys.errorUnknown),
              message: context.tr(state.errorKey ?? TranslationKeys.errorUnknown),
              actionLabel: context.tr(TranslationKeys.retry),
              onAction: () => context.read<RoomsListCubit>().load(),
            ),
            RoomsListStatus.success =>
              state.rooms.isEmpty
                  ? _refreshable(
                      context,
                      StatusView(
                        icon: Icons.weekend_outlined,
                        title: context.tr(TranslationKeys.roomsEmpty),
                        message: context.tr(TranslationKeys.roomsEmptyHint),
                      ),
                    )
                  : _success(context, state),
          };
        },
      ),
    );
  }

  Widget _success(BuildContext context, RoomsListState state) {
    final favorites = context.watch<FavoritesCubit>().state;
    final collection = context.watch<RoomsViewCubit>().state.collection;
    final shown = _filtered(state, favorites, collection);
    return Column(
      children: [
        _searchField(context),
        _filterChips(context, state, collection),
        Expanded(
          child: shown.isEmpty
              ? _refreshable(
                  context,
                  StatusView(
                    icon: Icons.search_off_rounded,
                    title: context.tr(TranslationKeys.roomsNoResults),
                    message: context.tr(TranslationKeys.roomsEmptyHint),
                  ),
                )
              : _grid(context, shown),
        ),
      ],
    );
  }

  Widget _searchField(BuildContext context) {
    final search = context.read<RoomsViewCubit>().search;
    final hasText = search.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: search,
        textInputAction: TextInputAction.search,
        onChanged: (v) => context.read<RoomsListCubit>().setQuery(v),
        decoration: InputDecoration(
          isDense: true,
          hintText: context.tr(TranslationKeys.searchRooms),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    context.read<RoomsViewCubit>().clear();
                    context.read<RoomsListCubit>().setQuery('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _filterChips(
    BuildContext context,
    RoomsListState state,
    RoomsCollection collection,
  ) {
    // Category keys present in the catalogue, ordered by the canonical list
    // first then any unknown/legacy values.
    final present = state.categories;
    final ordered = [
      ...kCategories.where(present.contains),
      ...present.where((c) => !kCategories.contains(c)),
    ];

    void setCollection(RoomsCollection c) =>
        context.read<RoomsViewCubit>().setCollection(c);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          FilterChip(
            avatar: const Icon(Icons.star_rounded, size: 18),
            label: Text(context.tr(TranslationKeys.favorites)),
            selected: collection == RoomsCollection.favorites,
            onSelected: (sel) =>
                setCollection(sel ? RoomsCollection.favorites : RoomsCollection.all),
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.history_rounded, size: 18),
            label: Text(context.tr(TranslationKeys.recent)),
            selected: collection == RoomsCollection.recent,
            onSelected: (sel) =>
                setCollection(sel ? RoomsCollection.recent : RoomsCollection.all),
          ),
          if (ordered.isNotEmpty || state.categoryFilter != null) ...[
            const _ChipDivider(),
            ChoiceChip(
              label: Text(context.tr(TranslationKeys.categoryAll)),
              selected: state.categoryFilter == null,
              onSelected: (_) => context.read<RoomsListCubit>().setCategory(null),
            ),
            for (final cat in ordered) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text(context.tr(categoryLabelKey(cat))),
                selected: state.categoryFilter == cat,
                onSelected: (_) =>
                    context.read<RoomsListCubit>().setCategory(cat),
              ),
            ],
          ],
        ],
      ),
    );
  }

  /// Wraps a non-scrolling [child] (an empty / no-results [StatusView]) so it
  /// fills the viewport and still responds to pull-to-refresh, mirroring the
  /// grid's own [RefreshIndicator]. Without the always-scrollable, viewport-
  /// height scroll view there'd be nothing for the drag gesture to grab.
  Widget _refreshable(BuildContext context, Widget child) {
    return RefreshIndicator(
      onRefresh: () => context.read<RoomsListCubit>().refresh(),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, List<Room> rooms) {
    return RefreshIndicator(
      onRefresh: () => context.read<RoomsListCubit>().refresh(),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 260,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.82,
        ),
        itemCount: rooms.length,
        itemBuilder: (context, i) {
          final room = rooms[i];
          return RoomCard(
            room: room,
            onTap: () async {
              // Await the room route so we can refresh on return — a room the
              // user deleted in there must drop out of this grid.
              await context.pushNamed(
                RoutesNames.room,
                pathParameters: {'slug': room.slug},
                extra: room,
              );
              if (context.mounted) context.read<RoomsListCubit>().refresh();
            },
          );
        },
      ),
    );
  }
}

/// A short vertical separator between the collection chips and the category
/// chips in the horizontal filter row.
class _ChipDivider extends StatelessWidget {
  const _ChipDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Center(
        child: Container(
          width: 1,
          height: 22,
          color: context.colors.outline,
        ),
      ),
    );
  }
}
