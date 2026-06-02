import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/constants/categories.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/status_view.dart';
import '/injections/injection.dart';
import '/logic/favorites/favorites_cubit.dart';
import '/logic/favorites/favorites_state.dart';
import '/routes/routes_names.dart';
import '../../domain/entities/room.dart';
import '../bloc/rooms_list/rooms_list_cubit.dart';
import '../bloc/rooms_list/rooms_list_state.dart';
import '../widgets/room_card.dart';
import '../widgets/settings_sheet.dart';

/// Which local collection the grid is scoped to, on top of the search +
/// category filters held by [RoomsListCubit].
enum _Collection { all, favorites, recent }

/// Home — the grid of every available room, with live viewer counts.
class RoomsPage extends StatelessWidget {
  const RoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<RoomsListCubit>(
      create: (_) => sl<RoomsListCubit>()..load(),
      child: const _RoomsView(),
    );
  }
}

class _RoomsView extends StatefulWidget {
  const _RoomsView();

  @override
  State<_RoomsView> createState() => _RoomsViewState();
}

class _RoomsViewState extends State<_RoomsView> {
  final _search = TextEditingController();
  _Collection _collection = _Collection.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Applies the favorites/recent collection on top of the cubit's already
  /// search- and category-filtered [RoomsListState.visibleRooms].
  List<Room> _filtered(RoomsListState state, FavoritesState favorites) {
    final rooms = state.visibleRooms;
    switch (_collection) {
      case _Collection.all:
        return rooms;
      case _Collection.favorites:
        return rooms.where((r) => favorites.favorites.contains(r.slug)).toList();
      case _Collection.recent:
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
                  ? StatusView(
                      icon: Icons.weekend_outlined,
                      title: context.tr(TranslationKeys.roomsEmpty),
                      message: context.tr(TranslationKeys.roomsEmptyHint),
                    )
                  : _success(context, state),
          };
        },
      ),
    );
  }

  Widget _success(BuildContext context, RoomsListState state) {
    final favorites = context.watch<FavoritesCubit>().state;
    final shown = _filtered(state, favorites);
    return Column(
      children: [
        _searchField(context),
        _filterChips(context, state),
        Expanded(
          child: shown.isEmpty
              ? StatusView(
                  icon: Icons.search_off_rounded,
                  title: context.tr(TranslationKeys.roomsNoResults),
                  message: context.tr(TranslationKeys.roomsEmptyHint),
                )
              : _grid(context, shown),
        ),
      ],
    );
  }

  Widget _searchField(BuildContext context) {
    final hasText = _search.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _search,
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
                    _search.clear();
                    context.read<RoomsListCubit>().setQuery('');
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _filterChips(BuildContext context, RoomsListState state) {
    // Category keys present in the catalogue, ordered by the canonical list
    // first then any unknown/legacy values.
    final present = state.categories;
    final ordered = [
      ...kCategories.where(present.contains),
      ...present.where((c) => !kCategories.contains(c)),
    ];

    void setCollection(_Collection c) => setState(() => _collection = c);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          FilterChip(
            avatar: const Icon(Icons.star_rounded, size: 18),
            label: Text(context.tr(TranslationKeys.favorites)),
            selected: _collection == _Collection.favorites,
            onSelected: (sel) =>
                setCollection(sel ? _Collection.favorites : _Collection.all),
          ),
          const SizedBox(width: 8),
          FilterChip(
            avatar: const Icon(Icons.history_rounded, size: 18),
            label: Text(context.tr(TranslationKeys.recent)),
            selected: _collection == _Collection.recent,
            onSelected: (sel) =>
                setCollection(sel ? _Collection.recent : _Collection.all),
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
            onTap: () => context.pushNamed(
              RoutesNames.room,
              pathParameters: {'slug': room.slug},
              extra: room,
            ),
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
