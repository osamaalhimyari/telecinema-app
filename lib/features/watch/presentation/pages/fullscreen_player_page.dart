import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/fullscreen_ui/fullscreen_ui_cubit.dart';
import '../bloc/fullscreen_ui/fullscreen_ui_state.dart';
import '../bloc/watch_cubit.dart';
import '../widgets/controls_lock_button.dart';
import '../widgets/floating_chat_overlay.dart';
import '../widgets/floating_reactions.dart';
import '../widgets/fullscreen_controls.dart';
import '../widgets/fullscreen_messages.dart';
import '../widgets/fullscreen_reaction_bar.dart';
import '../widgets/video_surface.dart';

/// Full-screen, landscape view of the room's video. Reuses the room's
/// [WatchCubit] (provided by the parent) for playback, and a page-scoped
/// [FullscreenUiCubit] for the overlay's UI state + the landscape/immersive
/// lifecycle — so the page itself is a plain StatelessWidget ().
class FullscreenPlayerPage extends StatelessWidget {
  const FullscreenPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Eager so creating the cubit forces landscape + immersive mode on entry,
      // and closing it (on pop) restores portrait + the system bars.
      lazy: false,
      create: (_) => FullscreenUiCubit(),
      child: const _FullscreenView(),
    );
  }
}

class _FullscreenView extends StatelessWidget {
  const _FullscreenView();

  @override
  Widget build(BuildContext context) {
    final watch = context.read<WatchCubit>();
    final ui = context.read<FullscreenUiCubit>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          VideoSurface(
            fullscreen: true,
            controlsVisibility: ui.controlsVisible,
            onToggleFullscreen: () => Navigator.of(context).maybePop(),
          ),
          // Reactions + chat float over the video. Both ignore pointers so taps
          // reach the player.
          FloatingReactions(stream: watch.reactions),
          FloatingChatOverlay(stream: watch.incomingChat),

          // Top-left: a single toggle button that reveals/hides the control
          // stack (emoji, messages, mic, lock) stacked under it.
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: BlocBuilder<FullscreenUiCubit, FullscreenUiState>(
                  builder: (context, state) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ControlsToggle(
                          expanded: state.controlsExpanded,
                          onTap: ui.toggleControls,
                        ),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topLeft,
                          child: !state.controlsExpanded
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const FullscreenReactionBar(),
                                      const SizedBox(height: 10),
                                      FullscreenMessagesButton(
                                        open: state.messagesOpen,
                                        onTap: ui.toggleMessages,
                                      ),
                                      const SizedBox(height: 10),
                                      const FullscreenVoiceButton(),
                                      const SizedBox(height: 10),
                                      const FullscreenLockButton(),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    );
                  },
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
                    FullscreenViewerCount(visibility: ui.controlsVisible),
                    const SizedBox(height: 8),
                    const FullscreenSpeakingIndicator(),
                  ],
                ),
              ),
            ),
          ),

          // The messages side panel slides in from the right when open.
          BlocBuilder<FullscreenUiCubit, FullscreenUiState>(
            buildWhen: (a, b) => a.messagesOpen != b.messagesOpen,
            builder: (context, state) => FullscreenMessagesPanel(
              open: state.messagesOpen,
              onClose: ui.closeMessages,
            ),
          ),
        ],
      ),
    );
  }
}

/// The master toggle that shows/hides the fullscreen control stack. Matches the
/// reaction/messages buttons' round style; fills in (primary tint) while open.
class _ControlsToggle extends StatelessWidget {
  const _ControlsToggle({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: expanded
          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.9)
          : Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            expanded ? Icons.close_rounded : Icons.tune_rounded,
            size: 22,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
