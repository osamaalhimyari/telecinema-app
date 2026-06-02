import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/voice/voice_cubit.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';
import '../pages/fullscreen_player_page.dart';
import 'external_player_view.dart';
import 'subtitle/subtitle_overlay.dart';
import 'video_surface.dart';

/// The 16:9 stage at the top of a room. For file rooms it shows the
/// [VideoSurface] (sync-aware video + controls, with a fullscreen toggle); for
/// embed rooms it shows the WebView plus the subtitle overlay.
class PlayerStage extends StatelessWidget {
  const PlayerStage({super.key});

  @override
  Widget build(BuildContext context) {
    // Fills whatever box the parent gives it (the room sizes this to ~half the
    // screen in portrait); the video is letterboxed to its real aspect ratio
    // inside [VideoSurface].
    return ColoredBox(
      color: Colors.black,
      child: BlocBuilder<WatchCubit, WatchState>(
        // Rebuild only when the *source/readiness* changes — not on every
        // position tick. The slider/controls live in VideoSurface, which has
        // its own (scoped) subscription.
        buildWhen: (a, b) =>
            a.isExternal != b.isExternal ||
            a.videoReady != b.videoReady ||
            a.videoError != b.videoError ||
            a.preparingTorrent != b.preparingTorrent ||
            a.externalUrl != b.externalUrl ||
            a.subtitleUrl != b.subtitleUrl ||
            a.subtitleSettings != b.subtitleSettings ||
            a.resyncTick != b.resyncTick ||
            a.lastSync != b.lastSync,
        builder: (context, state) {
          if (state.isExternal) return _external(context, state);
          return _file(context, state);
        },
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
          SubtitleOverlay(
            subtitleUrl: state.subtitleUrl!,
            lastSync: state.lastSync,
            settings: state.subtitleSettings,
          ),
      ],
    );
  }

  Widget _file(BuildContext context, WatchState state) {
    if (state.videoError) return _message(context, TranslationKeys.videoUnavailable);
    if (state.preparingTorrent) return _loading(context, TranslationKeys.preparingTorrent);
    if (!state.videoReady || context.read<WatchCubit>().videoController == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return VideoSurface(
      fullscreen: false,
      onToggleFullscreen: () => _openFullscreen(context),
    );
  }

  Widget _loading(BuildContext context, String key) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(context.tr(key), style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  /// Pushes the fullscreen view, handing it the *same* [WatchCubit] so playback
  /// keeps running in sync. `BlocProvider.value` does not close the cubit when
  /// the route is popped — the room page still owns it.
  void _openFullscreen(BuildContext context) {
    // Hand the fullscreen route the same cubits so playback stays in sync and
    // the push-to-talk mic keeps working. `.value` won't dispose them on pop.
    final watch = context.read<WatchCubit>();
    final voice = context.read<VoiceCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider<WatchCubit>.value(value: watch),
            BlocProvider<VoiceCubit>.value(value: voice),
          ],
          child: const FullscreenPlayerPage(),
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
}
