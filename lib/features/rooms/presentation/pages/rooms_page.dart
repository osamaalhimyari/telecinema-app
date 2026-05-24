import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/status_view.dart';
import '/injections/injection.dart';
import '/routes/routes_names.dart';
import '../bloc/rooms_list/rooms_list_cubit.dart';
import '../bloc/rooms_list/rooms_list_state.dart';
import '../widgets/room_card.dart';
import '../widgets/settings_sheet.dart';

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

class _RoomsView extends StatelessWidget {
  const _RoomsView();

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
                  : _grid(context, state),
          };
        },
      ),
    );
  }

  Widget _grid(BuildContext context, RoomsListState state) {
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
        itemCount: state.rooms.length,
        itemBuilder: (context, i) {
          final room = state.rooms[i];
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
