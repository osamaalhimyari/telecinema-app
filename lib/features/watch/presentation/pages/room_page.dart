import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/name_dialog.dart';
import '/core/shared/status_view.dart';
import '/features/rooms/domain/entities/room.dart';
import '/injections/injection.dart';
import '/logic/identity/identity_cubit.dart';
import '/logic/socket/socket_status_indicator.dart';
import '../bloc/voice/voice_cubit.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';
import '../widgets/chat_panel.dart';
import '../widgets/floating_reactions.dart';
import '../widgets/player_stage.dart';
import '../widgets/reaction_bar.dart';
import '../widgets/unlock_overlay.dart';
import '../widgets/viewers_panel.dart';
import '../widgets/voice_button.dart';
import '../widgets/wait_banner.dart';

/// The synchronized room: video/embed stage, chat, presence, reactions and
/// push-to-talk. Reachable from the grid (with the [Room] passed via `extra`)
/// or by deep link (fetched from the slug).
class RoomPage extends StatelessWidget {
  const RoomPage({super.key, required this.slug, this.initialRoom});

  final String slug;
  final Room? initialRoom;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<WatchCubit>(
          create: (_) => sl<WatchCubit>()..init(room: initialRoom, slug: slug),
        ),
        BlocProvider<VoiceCubit>(create: (_) => sl<VoiceCubit>()),
      ],
      child: const _RoomView(),
    );
  }
}

class _RoomView extends StatefulWidget {
  const _RoomView();

  @override
  State<_RoomView> createState() => _RoomViewState();
}

class _RoomViewState extends State<_RoomView> {
  StreamSubscription<void>? _throttleSub;

  @override
  void initState() {
    super.initState();
    // `chat_throttled` → tell the sender to slow down.
    _throttleSub = context.read<WatchCubit>().chatThrottled.listen((_) {
      if (mounted) context.showSnack(context.tr(TranslationKeys.chatThrottled));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureName());
  }

  /// On entering a room, require a display name if none is set yet. The name is
  /// saved once (changeable later from Settings); backing out leaves the room.
  Future<void> _ensureName() async {
    if (!mounted || context.read<IdentityCubit>().hasName) return;
    final named = await NameDialog.show(context);
    if (!named && mounted && context.canPop()) context.pop();
  }

  @override
  void dispose() {
    _throttleSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<WatchCubit, WatchState>(
      listenWhen: (a, b) => a.phase != b.phase && b.phase == WatchPhase.deleted,
      listener: (context, _) {
        context.showSnack(context.tr(TranslationKeys.roomDeleted));
        if (context.canPop()) context.pop();
      },
      child: BlocBuilder<WatchCubit, WatchState>(
        buildWhen: (a, b) => a.phase != b.phase || a.room != b.room,
        builder: (context, state) {
          return switch (state.phase) {
            WatchPhase.initializing => const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
            WatchPhase.error => Scaffold(
              appBar: AppBar(),
              body: StatusView(
                icon: Icons.error_outline_rounded,
                title: context.tr(state.errorKey ?? TranslationKeys.errorUnknown),
                actionLabel: context.tr(TranslationKeys.close),
                onAction: () => context.pop(),
              ),
            ),
            WatchPhase.locked => Scaffold(
              appBar: AppBar(title: Text(state.room?.name ?? '')),
              body: const UnlockOverlay(),
            ),
            WatchPhase.deleted ||
            WatchPhase.ready => const _RoomScaffold(),
          };
        },
      ),
    );
  }
}

class _RoomScaffold extends StatelessWidget {
  const _RoomScaffold();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<WatchCubit>().state;
    final room = state.room;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(room?.name ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                '${state.viewerCount} ${context.tr(TranslationKeys.watching)}',
                style: context.text.bodySmall,
              ),
            ],
          ),
          actions: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Center(child: SocketStatusIndicator()),
            ),
            _RoomMenu(state: state),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            // The video takes the top half of the screen in portrait; the
            // reaction bar, tabs and (now smaller) chat share the rest.
            final playerHeight = constraints.maxHeight * 0.5;
            return Column(
              children: [
                SizedBox(
                  height: playerHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const PlayerStage(),
                      FloatingReactions(stream: context.read<WatchCubit>().reactions),
                    ],
                  ),
                ),
                const WaitBanner(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Expanded(child: ReactionBar()),
                      const SizedBox(width: 8),
                      const VoiceButton(),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
                TabBar(
                  tabs: [
                    Tab(text: context.tr(TranslationKeys.chatTab)),
                    Tab(text: context.tr(TranslationKeys.viewersTab)),
                  ],
                ),
                const Expanded(
                  child: TabBarView(children: [ChatPanel(), ViewersPanel()]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Per-room actions: resync / change source / subtitle (embed rooms) and
/// delete (user-created rooms).
class _RoomMenu extends StatelessWidget {
  const _RoomMenu({required this.state});
  final WatchState state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WatchCubit>();
    final room = state.room;
    return PopupMenuButton<String>(
      onSelected: (value) => _handle(context, cubit, value),
      itemBuilder: (context) => [
        if (state.isExternal) ...[
          PopupMenuItem(value: 'resync', child: _item(Icons.sync_rounded, context.tr(TranslationKeys.resync))),
          PopupMenuItem(
            value: 'source',
            child: _item(Icons.swap_horiz_rounded, context.tr(TranslationKeys.changeSource)),
          ),
          PopupMenuItem(
            value: 'subtitle',
            child: _item(Icons.subtitles_outlined, context.tr(TranslationKeys.addSubtitle)),
          ),
        ],
        if (room?.isUserCreated ?? false)
          PopupMenuItem(
            value: 'delete',
            child: _item(Icons.delete_outline_rounded, context.tr(TranslationKeys.deleteRoom)),
          ),
        PopupMenuItem(
          value: 'leave',
          child: _item(Icons.logout_rounded, context.tr(TranslationKeys.leaveRoom)),
        ),
      ],
    );
  }

  Widget _item(IconData icon, String label) => Row(
    children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
  );

  Future<void> _handle(BuildContext context, WatchCubit cubit, String value) async {
    switch (value) {
      case 'resync':
        cubit.requestResync();
      case 'leave':
        if (context.canPop()) context.pop();
      case 'source':
        await _changeSource(context, cubit);
      case 'subtitle':
        await _pickSubtitle(context, cubit);
      case 'delete':
        await _delete(context, cubit);
    }
  }

  Future<void> _changeSource(BuildContext context, WatchCubit cubit) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr(TranslationKeys.changeSource)),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(hintText: ctx.tr(TranslationKeys.changeSourceUrlHint)),
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(), child: Text(ctx.tr(TranslationKeys.cancel))),
          FilledButton(
            onPressed: () => ctx.pop(controller.text.trim()),
            child: Text(ctx.tr(TranslationKeys.save)),
          ),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) cubit.changeSource(url);
  }

  Future<void> _pickSubtitle(BuildContext context, WatchCubit cubit) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final error = await cubit.uploadSubtitle(path);
    if (!context.mounted) return;
    context.showSnack(
      error == null
          ? context.tr(TranslationKeys.subtitleAdded)
          : context.tr(error),
    );
  }

  Future<void> _delete(BuildContext context, WatchCubit cubit) async {
    final needsPassword = state.room?.hasPassword ?? false;
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr(TranslationKeys.deleteRoom)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ctx.tr(TranslationKeys.deleteRoomConfirm)),
            if (needsPassword) ...[
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(labelText: ctx.tr(TranslationKeys.password)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => ctx.pop(false), child: Text(ctx.tr(TranslationKeys.cancel))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.error),
            onPressed: () => ctx.pop(true),
            child: Text(ctx.tr(TranslationKeys.delete)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await cubit.deleteRoom(
      password: needsPassword ? controller.text : null,
    );
    if (!context.mounted) return;
    if (error == null) {
      if (context.canPop()) context.pop();
    } else {
      context.showSnack(context.tr(error));
    }
  }
}
