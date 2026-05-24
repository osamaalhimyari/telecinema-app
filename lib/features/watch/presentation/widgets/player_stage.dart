import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';
import 'external_player_view.dart';
import 'subtitle/subtitle_overlay.dart';

/// The 16:9 stage at the top of a room. For file rooms it shows the
/// [VideoPlayer] with sync-aware controls; for embed rooms it shows the
/// WebView plus the subtitle overlay.
class PlayerStage extends StatefulWidget {
  const PlayerStage({super.key});

  @override
  State<PlayerStage> createState() => _PlayerStageState();
}

class _PlayerStageState extends State<PlayerStage> {
  bool _controlsVisible = true;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: Colors.black,
        child: BlocBuilder<WatchCubit, WatchState>(
          builder: (context, state) {
            if (state.isExternal) return _external(context, state);
            return _file(context, state);
          },
        ),
      ),
    );
  }

  Widget _external(BuildContext context, WatchState state) {
    final url = state.externalUrl;
    if (url == null || url.isEmpty) return _message(context, TranslationKeys.videoUnavailable);
    return Stack(
      fit: StackFit.expand,
      children: [
        ExternalPlayerView(url: url, resyncTick: state.resyncTick),
        if (state.subtitleUrl != null)
          SubtitleOverlay(subtitleUrl: state.subtitleUrl!, lastSync: state.lastSync),
      ],
    );
  }

  Widget _file(BuildContext context, WatchState state) {
    final cubit = context.read<WatchCubit>();
    final controller = cubit.controller;

    if (state.videoError) return _message(context, TranslationKeys.videoUnavailable);
    if (!state.videoReady || controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: () => setState(() => _controlsVisible = !_controlsVisible),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio == 0 ? 16 / 9 : controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
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
    );
  }

  Widget _controls(BuildContext context, WatchState state, WatchCubit cubit) {
    final pos = state.position;
    final dur = state.duration;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black54, Colors.transparent, Colors.black87],
          stops: const [0, 0.5, 1],
        ),
      ),
      child: Column(
        children: [
          const Spacer(),
          Center(
            child: IconButton.filled(
              iconSize: 36,
              style: IconButton.styleFrom(backgroundColor: Colors.white24),
              icon: Icon(state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              color: Colors.white,
              onPressed: cubit.togglePlay,
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
                      onChanged: (v) => cubit.emitLocalSeekPreview(Duration(milliseconds: v.toInt())),
                      onChangeEnd: (v) => cubit.seekTo(Duration(milliseconds: v.toInt())),
                    ),
                  ),
                ),
                Text(_fmt(dur), style: const TextStyle(color: Colors.white, fontSize: 12)),
                _speedMenu(context, state, cubit),
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

  Widget _message(BuildContext context, String key) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 40),
          const SizedBox(height: 8),
          Text(context.tr(key), style: const TextStyle(color: Colors.white70)),
        ],
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
