import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simple_pip_mode/simple_pip.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

/// Sync-aware video render + playback controls for a file room, shared by the
/// inline [PlayerStage] and the fullscreen page. The media_kit [VideoController]
/// is owned by the [WatchCubit], so the same instance drives both surfaces — the
/// fullscreen view stays in sync with the room for free.
///
/// [fullscreen] only swaps the toggle icon; [onToggleFullscreen] decides whether
/// tapping it pushes the fullscreen route or pops back to the room.
class VideoSurface extends StatefulWidget {
  const VideoSurface({
    super.key,
    required this.fullscreen,
    required this.onToggleFullscreen,
  });

  final bool fullscreen;
  final VoidCallback onToggleFullscreen;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  bool _controlsVisible = true;

  /// PiP is offered only inline (not in fullscreen) and only on Android.
  bool get _pipSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

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
    return Directionality(
      textDirection: TextDirection.ltr,
      child: GestureDetector(
        onTap: () => setState(() => _controlsVisible = !_controlsVisible),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // The Video widget letterboxes to the real aspect ratio on black.
            Video(controller: controller, controls: NoVideoControls, fit: BoxFit.contain),
            if (state.isBuffering) const Center(child: CircularProgressIndicator()),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: _controls(context, state, cubit),
              ),
            ),
          ],
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
                IconButton(
                  iconSize: 32,
                  color: Colors.white,
                  tooltip: '-10s',
                  icon: const Icon(Icons.replay_10_rounded),
                  onPressed: () => cubit.seekBy(const Duration(seconds: -10)),
                ),
                const SizedBox(width: 20),
                IconButton.filled(
                  iconSize: 36,
                  style: IconButton.styleFrom(backgroundColor: Colors.white24),
                  icon: Icon(state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  color: Colors.white,
                  onPressed: cubit.togglePlay,
                ),
                const SizedBox(width: 20),
                IconButton(
                  iconSize: 32,
                  color: Colors.white,
                  tooltip: '+10s',
                  icon: const Icon(Icons.forward_10_rounded),
                  onPressed: () => cubit.seekBy(const Duration(seconds: 10)),
                ),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text(_fmt(pos), style: const TextStyle(color: Colors.white, fontSize: 12)),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble(),
                      max: dur.inMilliseconds.toDouble().clamp(1, double.infinity),
                      activeColor: context.colors.primary,
                      inactiveColor: Colors.white30,
                      onChanged: (v) =>
                          cubit.emitLocalSeekPreview(Duration(milliseconds: v.toInt())),
                      onChangeEnd: (v) => cubit.seekTo(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                ),
                Text(_fmt(dur), style: const TextStyle(color: Colors.white, fontSize: 12)),
                _speedMenu(context, state, cubit),
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
                    widget.fullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
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

  Widget _speedMenu(BuildContext context, WatchState state, WatchCubit cubit) {
    return PopupMenuButton<double>(
      tooltip: context.tr(TranslationKeys.playbackSpeed),
      initialValue: state.playbackRate,
      onSelected: cubit.setRate,
      itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
          .map((r) => PopupMenuItem(value: r, child: Text('${r}x')))
          .toList(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          '${state.playbackRate}x',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
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
