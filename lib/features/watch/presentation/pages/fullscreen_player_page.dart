import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/watch_cubit.dart';
import '../widgets/floating_chat_overlay.dart';
import '../widgets/floating_reactions.dart';
import '../widgets/fullscreen_controls.dart';
import '../widgets/fullscreen_reaction_button.dart';
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
            onToggleFullscreen: () => Navigator.of(context).maybePop(),
          ),
          // Reactions + chat float over the video (the messages panel is hidden
          // in fullscreen). Both ignore pointers so taps reach the player.
          FloatingReactions(stream: cubit.reactions),
          FloatingChatOverlay(stream: cubit.incomingChat),
          // Collapsible reaction palette, pinned top-left.
          const SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: FullscreenReactionButton(),
              ),
            ),
          ),
          // Chat + push-to-talk, pinned top-right.
          const SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FullscreenChatButton(),
                    SizedBox(width: 10),
                    FullscreenVoiceButton(),
                  ],
                ),
              ),
            ),
          ),
          // "<name> speaking" indicator, top-center.
          const SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: FullscreenSpeakingIndicator(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
