import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:simple_pip_mode/actions/pip_action.dart';
import 'package:simple_pip_mode/actions/pip_actions_layout.dart';
import 'package:simple_pip_mode/pip_widget.dart';
import 'package:simple_pip_mode/simple_pip.dart';

import '/core/config/app_config.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/name_dialog.dart';
import '/core/shared/status_view.dart';
import '/features/cache/presentation/widgets/download_button.dart';
import '/features/rooms/domain/entities/room.dart';
import '/injections/injection.dart';
import '/logic/identity/identity_cubit.dart';
import '/logic/socket/socket_status_indicator.dart';
import '/routes/routes_names.dart';
import '../bloc/chat_divider/chat_divider_cubit.dart';
import '../bloc/chat_divider/chat_divider_state.dart';
import '../bloc/draw_mode/draw_mode_cubit.dart';
import '../bloc/voice/voice_cubit.dart';
import '../bloc/voice_playback/voice_playback_cubit.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/chat_panel.dart';
import '../widgets/controls_lock_button.dart';
import '../widgets/draw_toggle_button.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/drawing_overlay.dart';
import '../widgets/floating_chat_overlay.dart';
import '../widgets/floating_reactions.dart';
import '../widgets/player_stage.dart';
import '../widgets/presence_notices.dart';
import '../widgets/reaction_bar.dart';
import '../widgets/subtitle/subtitle_settings_sheet.dart';
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
        BlocProvider<DrawModeCubit>(create: (_) => DrawModeCubit()),
        BlocProvider<ChatDividerCubit>(create: (_) => ChatDividerCubit()),
        // Shared chat voice-message player (one clip plays at a time).
        BlocProvider<VoicePlaybackCubit>(create: (_) => VoicePlaybackCubit()),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureName();
      _enableAutoPip();
    });
  }

  /// On entering a room, require a display name if none is set yet. The name is
  /// saved once (changeable later from Settings); backing out leaves the room.
  Future<void> _ensureName() async {
    if (!mounted || context.read<IdentityCubit>().hasName) return;
    final named = await NameDialog.show(context);
    if (!named && mounted && context.canPop()) context.pop();
  }

  /// PiP is Android-only (and not on web).
  bool get _pipSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Enable Android 12+ auto-enter PiP while in this room, so leaving the app
  /// floats the video. Disabled again when the room is left.
  Future<void> _enableAutoPip() async {
    if (!_pipSupported) return;
    try {
      if (await SimplePip.isAutoPipAvailable) {
        await SimplePip().setAutoPipMode();
      }
    } catch (_) {
      /* unsupported on this device */
    }
  }

  void _disableAutoPip() {
    if (!_pipSupported) return;
    try {
      SimplePip().setAutoPipMode(autoEnter: false);
    } catch (_) {}
  }

  /// Maps the PiP window's system buttons to room playback (which syncs all).
  void _onPipAction(PipAction action) {
    final cubit = context.read<WatchCubit>();
    switch (action) {
      case PipAction.play:
        if (!cubit.state.isPlaying) cubit.togglePlay();
      case PipAction.pause:
        if (cubit.state.isPlaying) cubit.togglePlay();
      case PipAction.rewind:
        cubit.seekBy(const Duration(seconds: -10));
      case PipAction.forward:
        cubit.seekBy(const Duration(seconds: 10));
      default:
        break;
    }
  }

  @override
  void dispose() {
    _throttleSub?.cancel();
    _disableAutoPip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = BlocListener<WatchCubit, WatchState>(
      listenWhen: (a, b) =>
          a.phase != b.phase || a.videoReady != b.videoReady,
      listener: (context, state) {
        if (state.phase == WatchPhase.deleted) {
          context.showSnack(context.tr(TranslationKeys.roomDeleted));
          if (context.canPop()) context.pop();
        } else if (state.phase == WatchPhase.ready || state.videoReady) {
          // Re-arm auto-PiP once the room is ready AND again once the video
          // surface actually exists — the initState post-frame call (and even the
          // `ready` phase) can run before the surface is up, which on some devices
          // is too early for the system to honor auto-enter.
          _enableAutoPip();
        }
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
                title: context.tr(
                  state.errorKey ?? TranslationKeys.errorUnknown,
                ),
                actionLabel: context.tr(TranslationKeys.close),
                onAction: () => context.pop(),
              ),
            ),
            WatchPhase.locked => Scaffold(
              appBar: AppBar(title: Text(state.room?.name ?? '')),
              body: const UnlockOverlay(),
            ),
            WatchPhase.deleted || WatchPhase.ready => const _RoomScaffold(),
          };
        },
      ),
    );

    if (!_pipSupported) return content;
    // Android Picture-in-Picture: floats the video over other apps. The PiP
    // window shows just the video (pipChild); system buttons drive playback,
    // and setIsPlaying keeps the play/pause icon in sync.
    return BlocListener<WatchCubit, WatchState>(
      listenWhen: (a, b) => a.isPlaying != b.isPlaying,
      listener: (_, state) => SimplePip().setIsPlaying(state.isPlaying),
      child: PipWidget(
        pipLayout: PipActionsLayout.mediaWithSeek10,
        onPipAction: _onPipAction,
        onPipEntered: () => SimplePip().setIsPlaying(
          context.read<WatchCubit>().state.isPlaying,
        ),
        pipChild: const _PipVideoView(),
        child: content,
      ),
    );
  }
}

/// The video view shown inside the Android PiP window. Reactions, chat and
/// join/leave notices float over it too, so backgrounding the app from portrait
/// keeps them visible — matching the fullscreen surface (which Android captures
/// whole, overlays and all).
class _PipVideoView extends StatelessWidget {
  const _PipVideoView();

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<WatchCubit>();
    final controller = cubit.videoController;
    // The PiP window is rendered outside the Scaffold/Material of the room, so
    // its text (chat + join/leave) and emoji would otherwise paint with Flutter's
    // "no Material" debug style — the yellow underline. A transparent Material
    // (with an explicit Directionality) supplies a real default text style and
    // kills the underline, without adding any background of its own.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        type: MaterialType.transparency,
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (controller == null)
                const SizedBox.expand()
              else
                Video(
                  controller: controller,
                  controls: NoVideoControls,
                  fit: BoxFit.contain,
                ),
              FloatingReactions(stream: cubit.reactions),
              FloatingChatOverlay(stream: cubit.incomingChat),
              PresenceNotices(stream: cubit.presenceNotices),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomScaffold extends StatelessWidget {
  const _RoomScaffold();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          titleSpacing: 0,
          // Only the title and menu read state — and only room/viewerCount, not
          // the video position which ticks several times a second. Scoping these
          // keeps a position tick from rebuilding the whole screen (which would
          // make incoming reactions/chat feel laggy).
          title: BlocBuilder<WatchCubit, WatchState>(
            buildWhen: (a, b) =>
                a.room != b.room || a.viewerCount != b.viewerCount,
            builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Tapping the (possibly truncated) name surfaces it in full as
                // a snack — handy when the room title is ellipsized.
                GestureDetector(
                  onTap: () {
                    final name = state.room?.name ?? '';
                    if (name.isNotEmpty) context.showSnack(name);
                  },
                  child: Text(
                    state.room?.name ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${state.viewerCount} ${context.tr(TranslationKeys.watching)}',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Center(child: SocketStatusIndicator()),
            ),
            BlocBuilder<WatchCubit, WatchState>(
              // Rebuild on subtitle changes too, so the "Subtitle settings"
              // entry appears the moment a subtitle is added (its visibility
              // depends on `subtitleUrl`, not just `room`).
              buildWhen: (a, b) => a.room != b.room || a.subtitleUrl != b.subtitleUrl,
              builder: (context, state) => _RoomMenu(state: state),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final totalHeight = constraints.maxHeight;
            const handleHeight = 20.0;
            // Guard against degenerate/transient constraints (e.g. a mid-
            // keyboard-animation frame giving maxHeight <= handleHeight): a
            // non-positive availableHeight would make the fraction math produce
            // negative SizedBox heights and throw.
            final availableHeight = (totalHeight - handleHeight).clamp(
              0.0,
              double.infinity,
            );

            return BlocBuilder<ChatDividerCubit, ChatDividerState>(
              builder: (context, divider) {
                final minFraction =
                    (ChatDividerCubit.minBottomHeight / availableHeight)
                        .clamp(0.0, ChatDividerCubit.maxFraction);
                final clampedFraction =
                    divider.fraction.clamp(minFraction, ChatDividerCubit.maxFraction);
                final bottomHeight = availableHeight * clampedFraction;
                final videoHeight = availableHeight - bottomHeight;

                return Column(
                  children: [
                    // Top section: just the video player — fills all available
                    // space; the Video widget letterboxes to the real aspect ratio.
                    SizedBox(
                      height: videoHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const PlayerStage(),
                          FloatingReactions(
                            stream: context.read<WatchCubit>().reactions,
                          ),
                          PresenceNotices(
                            stream: context.read<WatchCubit>().presenceNotices,
                          ),
                          DrawingOverlay(
                            stream: context.read<WatchCubit>().drawings,
                          ),
                          const DrawingCanvas(),
                        ],
                      ),
                    ),
                    // Drag handle
                    GestureDetector(
                      onVerticalDragUpdate: (details) {
                        context.read<ChatDividerCubit>().setFraction(
                          ((bottomHeight - details.delta.dy) / availableHeight),
                          availableHeight: availableHeight,
                        );
                      },
                      child: Container(
                        height: handleHeight,
                        color: Colors.transparent,
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Bottom section: buttons + reaction bar + chat
                    SizedBox(
                      height: bottomHeight,
                      child: Column(
                        children: [
                          const WaitBanner(),
                          // Action buttons row — emojis moved to their own row below it.
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                const Spacer(),
                                const VoiceButton(),
                                const SizedBox(width: 4),
                                const BookmarkButton(),
                                const SizedBox(width: 4),
                                const DownloadButton(),
                                const DrawToggleButton(),
                                const ControlsLockButton(),
                                const SizedBox(width: 8),
                              ],
                            ),
                          ),
                          // Emoji reaction strip, on its own row under the buttons.
                          const Padding(
                            padding: EdgeInsets.only(top: 2, bottom: 6),
                            child: ReactionBar(),
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
                      ),
                    ),
                  ],
                );
              },
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
          PopupMenuItem(
            value: 'resync',
            child: _item(
              Icons.sync_rounded,
              context.tr(TranslationKeys.resync),
            ),
          ),
          PopupMenuItem(
            value: 'source',
            child: _item(
              Icons.swap_horiz_rounded,
              context.tr(TranslationKeys.changeSource),
            ),
          ),
        ],
        // Subtitles work for every room type (file rooms load it as a track,
        // external rooms as an overlay).
        PopupMenuItem(
          value: 'subtitle',
          child: _item(
            Icons.subtitles_outlined,
            context.tr(TranslationKeys.addSubtitle),
          ),
        ),
        // Find a subtitle online (OpenSubtitles) instead of uploading a file.
        PopupMenuItem(
          value: 'online_subtitle',
          child: _item(
            Icons.translate_rounded,
            context.tr(TranslationKeys.downloadSubtitle),
          ),
        ),
        // Tune the loaded subtitle (timing/thickness/size), shared with the room.
        if (state.subtitleUrl != null)
          PopupMenuItem(
            value: 'subtitle_settings',
            child: _item(
              Icons.tune_rounded,
              context.tr(TranslationKeys.subtitleSettings),
            ),
          ),
        if ((room?.slug ?? '').isNotEmpty)
          PopupMenuItem(
            value: 'share',
            child: _item(
              Icons.share_rounded,
              context.tr(TranslationKeys.share),
            ),
          ),
        if (room?.isUserCreated ?? false)
          PopupMenuItem(
            value: 'delete',
            child: _item(
              Icons.delete_outline_rounded,
              context.tr(TranslationKeys.deleteRoom),
            ),
          ),
        PopupMenuItem(
          value: 'leave',
          child: _item(
            Icons.logout_rounded,
            context.tr(TranslationKeys.leaveRoom),
          ),
        ),
      ],
    );
  }

  Widget _item(IconData icon, String label) => Row(
    children: [Icon(icon, size: 18), const SizedBox(width: 10), Text(label)],
  );

  Future<void> _handle(
    BuildContext context,
    WatchCubit cubit,
    String value,
  ) async {
    switch (value) {
      case 'resync':
        cubit.requestResync();
      case 'leave':
        if (context.canPop()) context.pop();
      case 'source':
        await _changeSource(context, cubit);
      case 'subtitle':
        await _pickSubtitle(context, cubit);
      case 'online_subtitle':
        _openOnlineSubtitles(context);
      case 'subtitle_settings':
        await showSubtitleSettingsSheet(context, cubit);
      case 'share':
        await _share(context, state.room);
      case 'delete':
        await _delete(context, cubit);
    }
  }

  /// Opens a share sheet for the room's deep link: a QR to scan, plus copy and
  /// system-share actions. The link points at `/room/:slug`, which the router
  /// deep-links straight into this page.
  Future<void> _share(BuildContext context, Room? room) async {
    final slug = room?.slug ?? '';
    if (slug.isEmpty) return;
    final url = AppConfig.roomUrl(slug);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                room?.name ?? ctx.tr(TranslationKeys.shareRoom),
                style: ctx.text.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: QrImageView(
                  data: url,
                  size: 200,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(ctx.tr(TranslationKeys.scanToJoin), style: ctx.text.bodySmall),
              const SizedBox(height: 4),
              SelectableText(
                url,
                textAlign: TextAlign.center,
                style: ctx.text.bodySmall,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      if (context.mounted) {
                        context.showSnack(context.tr(TranslationKeys.linkCopied));
                      }
                    },
                    icon: const Icon(Icons.copy_rounded),
                    label: Text(ctx.tr(TranslationKeys.copyLink)),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      await SharePlus.instance.share(
                        ShareParams(text: url, subject: room?.name),
                      );
                    },
                    icon: const Icon(Icons.ios_share_rounded),
                    label: Text(ctx.tr(TranslationKeys.share)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
          decoration: InputDecoration(
            hintText: ctx.tr(TranslationKeys.changeSourceUrlHint),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(),
            child: Text(ctx.tr(TranslationKeys.cancel)),
          ),
          FilledButton(
            onPressed: () => ctx.pop(controller.text.trim()),
            child: Text(ctx.tr(TranslationKeys.save)),
          ),
        ],
      ),
    );
    if (url != null && url.isNotEmpty) cubit.changeSource(url);
  }

  /// Opens the OpenSubtitles search page for this room. The chosen subtitle is
  /// uploaded there and arrives back through the room's `subtitle_changed`
  /// listener — so no result needs to flow back to this page.
  void _openOnlineSubtitles(BuildContext context) {
    final room = state.room;
    if (room == null || room.slug.isEmpty) return;
    context.pushNamed(
      RoutesNames.subtitles,
      pathParameters: {'slug': room.slug},
      // `videoFilename` is the torrent/file release name (carries the `SxxExx`
      // the subtitle search needs); `magnet` is the fallback name source when no
      // file has been resolved yet.
      extra: {
        'imdbId': room.imdbId,
        'title': room.name,
        'release': room.videoFilename,
        'magnet': room.magnet,
      },
    );
  }

  Future<void> _pickSubtitle(BuildContext context, WatchCubit cubit) async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['srt', 'vtt'],
    );
    final path = file?.path;
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
                decoration: InputDecoration(
                  labelText: ctx.tr(TranslationKeys.password),
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => ctx.pop(false),
            child: Text(ctx.tr(TranslationKeys.cancel)),
          ),
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
