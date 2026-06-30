import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/watch_cubit.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/draw_toggle_button.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/drawing_overlay.dart';
import '../widgets/floating_chat_overlay.dart';
import '../widgets/floating_reactions.dart';
import '../widgets/fullscreen_bookmarks_panel.dart';
import '../widgets/fullscreen_controls.dart';
import '../widgets/fullscreen_messages.dart';
import '../widgets/fullscreen_reaction_bar.dart';
import '../widgets/video_surface.dart';

/// Full-screen, landscape view of the room's video. It reuses the room's
/// [WatchCubit] (passed in via `BlocProvider.value`) and therefore its media_kit
/// player, so playback stays in sync with the room. Forces landscape + immersive
/// system UI on entry and restores the defaults on exit.
class FullscreenPlayerPage extends StatefulWidget {
  const FullscreenPlayerPage({super.key});

  @override
  State<FullscreenPlayerPage> createState() => _FullscreenPlayerPageState();
}

class _FullscreenPlayerPageState extends State<FullscreenPlayerPage> {
  /// Shared with [VideoSurface]: the playback controls toggle this on tap, and
  /// the viewer count overlay rides the same flag so it hides/appears with them.
  final ValueNotifier<bool> _controlsVisible = ValueNotifier<bool>(true);

  /// Whether the side messages panel is open.
  bool _messagesOpen = false;

  /// Whether the side bookmarks panel is open (mutually exclusive with messages).
  bool _bookmarksOpen = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _controlsVisible.dispose();
    // Restore the app's portrait layout and the system bars.
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WatchCubit>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          VideoSurface(
            fullscreen: true,
            controlsVisibility: _controlsVisible,
            onToggleFullscreen: () => Navigator.of(context).maybePop(),
          ),
          // Reactions + chat float over the video. Both ignore pointers so taps
          // reach the player.
          FloatingReactions(stream: cubit.reactions),
          FloatingChatOverlay(stream: cubit.incomingChat),
          // On-video drawing: strokes render under the capture canvas, which
          // only intercepts touches while draw mode is engaged.
          DrawingOverlay(stream: cubit.drawings),
          const DrawingCanvas(),

          // Top-left: the collapsible reaction palette, with the messages
          // toggle stacked right beneath it.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FullscreenReactionBar(),
                    const SizedBox(height: 10),
                    FullscreenMessagesButton(
                      open: _messagesOpen,
                      onTap: () => setState(() {
                        _messagesOpen = !_messagesOpen;
                        if (_messagesOpen) _bookmarksOpen = false;
                      }),
                    ),
                    const SizedBox(height: 10),
                    const FullscreenDrawButton(),
                    const SizedBox(height: 10),
                    FullscreenBookmarkButton(
                      open: _bookmarksOpen,
                      onTap: () => setState(() {
                        _bookmarksOpen = !_bookmarksOpen;
                        if (_bookmarksOpen) _messagesOpen = false;
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top-center: viewer count (hides with the controls) above the
          // "who's speaking" indicator (always visible).
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FullscreenViewerCount(visibility: _controlsVisible),
                    const SizedBox(height: 8),
                    const FullscreenSpeakingIndicator(),
                  ],
                ),
              ),
            ),
          ),

          // Top-right: tap-to-talk microphone.
          const SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: FullscreenVoiceButton(),
              ),
            ),
          ),

          // The messages side panel sits above the overlays; it slides in from
          // the right while the top-left toggle stays reachable to close it.
          FullscreenMessagesPanel(
            open: _messagesOpen,
            onClose: () => setState(() => _messagesOpen = false),
          ),
          FullscreenBookmarksPanel(
            open: _bookmarksOpen,
            onClose: () => setState(() => _bookmarksOpen = false),
          ),
        ],
      ),
    );
  }
}
