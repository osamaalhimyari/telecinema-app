import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_pip_mode/simple_pip.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../../domain/entities/bookmark.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

/// Sync-aware video render + playback controls for a file room, shared by the
/// inline [PlayerStage] and the fullscreen page. The media_kit [VideoController]
/// is owned by the [WatchCubit], so the same instance drives both surfaces — the
/// fullscreen view stays in sync with the room for free.
///
/// [fullscreen] only swaps the toggle icon; [onToggleFullscreen] decides whether
/// tapping it pushes the fullscreen route or pops back to the room.
///
/// [controlsVisibility] lets a parent share the controls' show/hide flag (the
/// fullscreen page passes one so sibling overlays — e.g. the viewer count — can
/// fade in and out together with the controls). When null, the surface keeps
/// its own internal flag (the inline case).
class VideoSurface extends StatefulWidget {
  const VideoSurface({
    super.key,
    required this.fullscreen,
    required this.onToggleFullscreen,
    this.controlsVisibility,
  });

  final bool fullscreen;
  final VoidCallback onToggleFullscreen;
  final ValueNotifier<bool>? controlsVisibility;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  /// Used only when no shared notifier is supplied by the parent.
  ValueNotifier<bool>? _ownVisibility;

  /// Idle countdown that fades the controls out after [_idleTimeout] of no
  /// interaction. Re-armed every time they're shown or a control is touched.
  Timer? _hideTimer;
  static const Duration _idleTimeout = Duration(seconds: 5);

  ValueNotifier<bool> get _visible =>
      widget.controlsVisibility ??
      (_ownVisibility ??= ValueNotifier<bool>(true));

  @override
  void initState() {
    super.initState();
    // Controls start visible; arm the auto-hide so they fade on their own.
    _restartHideTimer();
  }

  /// Tap on the video: hide immediately if showing, otherwise show + arm the
  /// auto-hide. A no-op while the per-user touch lock is on.
  void _toggleControls() {
    if (context.read<WatchCubit>().state.controlsLocked) return;
    if (_visible.value) {
      _hideTimer?.cancel();
      _visible.value = false;
    } else {
      _visible.value = true;
      _restartHideTimer();
    }
  }

  /// Keep the controls up and reset the idle countdown — called whenever the
  /// user touches a control so they never vanish mid-interaction.
  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_idleTimeout, () {
      if (mounted) _visible.value = false;
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _ownVisibility?.dispose();
    super.dispose();
  }

  /// PiP is offered only inline (not in fullscreen) and only on Android.
  bool get _pipSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WatchCubit>();
    final controller = cubit.videoController;
    final state = context.watch<WatchCubit>().state;

    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // The player and its controls always read left-to-right — a seek bar that
    // filled and skipped backwards under Arabic (RTL) would be confusing. The
    // surrounding app stays RTL; only this player subtree is pinned to LTR.
    return BlocListener<WatchCubit, WatchState>(
      // When the user locks touch, drop the controls immediately so a ghost
      // touch can't catch them mid-fade.
      listenWhen: (a, b) => a.controlsLocked != b.controlsLocked,
      listener: (context, s) {
        if (s.controlsLocked) {
          _hideTimer?.cancel();
          _visible.value = false;
        }
      },
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GestureDetector(
          onTap: state.controlsLocked ? null : _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // The Video widget letterboxes to the real aspect ratio on black.
              // media_kit renders the active subtitle via this Flutter overlay, so
              // the room's shared weight/size drive its style. (Timing is applied
              // separately through libmpv's `sub-delay`.)
              Video(
                controller: controller,
                controls: NoVideoControls,
                fit: BoxFit.contain,
                subtitleViewConfiguration: SubtitleViewConfiguration(
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: state.subtitleSettings.size.toDouble(),
                    fontWeight: state.subtitleSettings.fontWeight,
                    height: 1.3,
                    backgroundColor: const Color(0xAA000000),
                  ),
                ),
              ),
              if (state.isBuffering)
                const Center(child: CircularProgressIndicator()),
              ValueListenableBuilder<bool>(
                valueListenable: _visible,
                builder: (context, visible, _) => AnimatedOpacity(
                  opacity: visible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: IgnorePointer(
                    ignoring: !visible || state.controlsLocked,
                    child: _controls(context, state, cubit),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(BuildContext context, WatchState state, WatchCubit cubit) {
    final pos = state.position;
    final dur = state.duration;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.black87],
          stops: [0, 0.5, 1],
        ),
      ),
      child: Column(
        children: [
          const Spacer(),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live TV has no timeline — skip the ±10s seek buttons.
                if (!state.isLive) ...[
                  IconButton(
                    iconSize: 32,
                    color: Colors.white,
                    tooltip: '-10s',
                    icon: const Icon(Icons.replay_10_rounded),
                    onPressed: () {
                      cubit.seekBy(const Duration(seconds: -10));
                      _restartHideTimer();
                    },
                  ),
                  const SizedBox(width: 20),
                ],
                IconButton.filled(
                  iconSize: 36,
                  style: IconButton.styleFrom(backgroundColor: Colors.white24),
                  icon: Icon(
                    state.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  color: Colors.white,
                  onPressed: () {
                    cubit.togglePlay();
                    _restartHideTimer();
                  },
                ),
                if (!state.isLive) ...[
                  const SizedBox(width: 20),
                  IconButton(
                    iconSize: 32,
                    color: Colors.white,
                    tooltip: '+10s',
                    icon: const Icon(Icons.forward_10_rounded),
                    onPressed: () {
                      cubit.seekBy(const Duration(seconds: 10));
                      _restartHideTimer();
                    },
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                // Live TV: no scrubber/time/speed (the stream rides the live
                // edge) — just a LIVE badge, then the PiP/fullscreen controls.
                if (state.isLive) ...[
                  _liveLabel(context),
                  const Spacer(),
                ] else ...[
                  Text(
                    _fmt(pos),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 24,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 12,
                              ),
                            ),
                            child: Slider(
                              value: pos.inMilliseconds
                                  .clamp(0, dur.inMilliseconds)
                                  .toDouble(),
                              max: dur.inMilliseconds.toDouble().clamp(
                                1,
                                double.infinity,
                              ),
                              activeColor: context.colors.primary,
                              inactiveColor: Colors.white30,
                              onChanged: (v) {
                                cubit.emitLocalSeekPreview(
                                  Duration(milliseconds: v.toInt()),
                                );
                                _restartHideTimer();
                              },
                              onChangeEnd: (v) => cubit.seekTo(
                                Duration(milliseconds: v.toInt()),
                              ),
                            ),
                          ),
                          IgnorePointer(child: _bookmarkTicks(context, dur)),
                        ],
                      ),
                    ),
                  ),
                  Text(
                    _fmt(dur),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  _qualityMenu(context, state, cubit),
                  _speedMenu(context, state, cubit),
                  _syncOffsetButton(context, state, cubit),
                ],
                if (!widget.fullscreen && _pipSupported)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    color: Colors.white,
                    tooltip: context.tr(TranslationKeys.pictureInPicture),
                    icon: const Icon(Icons.picture_in_picture_alt_rounded),
                    onPressed: () => SimplePip().enterPipMode(),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  color: Colors.white,
                  tooltip: context.tr(TranslationKeys.fullscreen),
                  icon: Icon(
                    widget.fullscreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                  ),
                  onPressed: widget.onToggleFullscreen,
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  /// Small red "LIVE" pill shown in place of the scrubber for live-TV rooms.
  Widget _liveLabel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        context.tr(TranslationKeys.tvLive),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _speedMenu(BuildContext context, WatchState state, WatchCubit cubit) {
    return PopupMenuButton<double>(
      tooltip: context.tr(TranslationKeys.playbackSpeed),
      initialValue: state.playbackRate,
      onSelected: cubit.setRate,
      itemBuilder: (_) => [
        0.5,
        0.75,
        1.0,
        1.25,
        1.5,
        2.0,
      ].map((r) => PopupMenuItem(value: r, child: Text('${r}x'))).toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          '${state.playbackRate}x',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  /// Per-viewer sync nudge — only for `local` rooms, where each viewer plays
  /// their own (possibly slightly different) file. Opens a small panel to shift
  /// THIS device's timeline ± seconds so the picture lines up with the room;
  /// never synced to anyone else.
  Widget _syncOffsetButton(
    BuildContext context,
    WatchState state,
    WatchCubit cubit,
  ) {
    if (!(state.room?.roomType.isLocal ?? false)) return const SizedBox.shrink();
    return IconButton(
      visualDensity: VisualDensity.compact,
      color: Colors.white,
      tooltip: context.tr(TranslationKeys.syncOffset),
      icon: const Icon(Icons.published_with_changes_rounded),
      onPressed: () {
        _restartHideTimer();
        _showSyncOffsetSheet(context, cubit);
      },
    );
  }

  void _showSyncOffsetSheet(BuildContext context, WatchCubit cubit) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) {
          void nudge(double d) {
            cubit.nudgeSyncOffset(d);
            setSheetState(() {});
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr(TranslationKeys.syncOffset),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _offsetChip(context, '-5s', () => nudge(-5)),
                    _offsetChip(context, '-0.5s', () => nudge(-0.5)),
                    SizedBox(
                      width: 76,
                      child: Text(
                        _fmtOffset(cubit.state.syncOffsetSeconds),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _offsetChip(context, '+0.5s', () => nudge(0.5)),
                    _offsetChip(context, '+5s', () => nudge(5)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _offsetChip(BuildContext context, String label, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white38),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }

  /// e.g. `0s`, `+2.5s`, `-0.5s` (negative already carries its own sign).
  String _fmtOffset(double s) {
    final str = s.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
    return '${s > 0 ? '+' : ''}${str}s';
  }

  /// Quality selector for adaptive-HLS file rooms: "Auto" (libmpv adapts across
  /// the server ladder), the pinned variants the server actually offers, and the
  /// progressive "Original". Hidden for rooms the server can't transcode
  /// (torrent/youtube/external/tv). The choice is client-only — it re-opens the
  /// player at the current position and is never synced to the room. The pinned
  /// rungs come from the parsed master playlist (state.qualities), so the menu
  /// matches whatever ladder the server is configured for.
  Widget _qualityMenu(
    BuildContext context,
    WatchState state,
    WatchCubit cubit,
  ) {
    final room = state.room;
    if (room == null || !room.supportsHls) return const SizedBox.shrink();

    final options = <MapEntry<String, String?>>[
      MapEntry('Auto', room.hlsUrl),
      for (final q in state.qualities) MapEntry(q.label, q.url),
      MapEntry('Original', room.videoUrl),
    ].where((e) => e.value != null).toList();
    if (options.isEmpty) return const SizedBox.shrink();

    // Null selection means the default the cubit opened, i.e. "Auto" (master).
    final selected = cubit.selectedQualityUrl ?? room.hlsUrl;

    return PopupMenuButton<String>(
      tooltip: 'Quality',
      initialValue: selected,
      onSelected: (url) {
        cubit.setQuality(url);
        _restartHideTimer();
      },
      itemBuilder: (_) => options
          .map(
            (e) => PopupMenuItem<String>(
              value: e.value!,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    e.value == selected ? Icons.check_rounded : null,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(e.key),
                ],
              ),
            ),
          )
          .toList(),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(Icons.high_quality_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  List<Bookmark> _loadBookmarks() => context.read<WatchCubit>().loadBookmarks();

  /// Small vertical lines on the seekbar at each bookmark's position.
  Widget _bookmarkTicks(BuildContext context, Duration duration) {
    if (duration.inMilliseconds <= 0) return const SizedBox.shrink();
    final bookmarks = _loadBookmarks();
    if (bookmarks.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        const horizontalPadding = 12.0;
        final trackWidth = constraints.maxWidth - horizontalPadding * 2;
        if (trackWidth <= 0) return const SizedBox.shrink();
        return Stack(
          fit: StackFit.expand,
          children: [
            for (final b in bookmarks)
              Positioned(
                left:
                    horizontalPadding +
                    (b.position.inMilliseconds / duration.inMilliseconds).clamp(
                          0.0,
                          1.0,
                        ) *
                        trackWidth -
                    1,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
