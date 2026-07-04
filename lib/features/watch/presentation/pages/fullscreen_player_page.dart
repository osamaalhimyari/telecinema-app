import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/fullscreen_ui/fullscreen_ui_cubit.dart';
import '../bloc/fullscreen_ui/fullscreen_ui_state.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';
import '../widgets/bookmark_button.dart';
import '../widgets/controls_lock_button.dart';
import '../widgets/draw_toggle_button.dart';
import '../widgets/drawing_canvas.dart';
import '../widgets/drawing_overlay.dart';
import '../widgets/floating_chat_overlay.dart';
import '../widgets/floating_reactions.dart';
import '../widgets/fullscreen_bookmarks_panel.dart';
import '../widgets/fullscreen_controls.dart';
import '../widgets/fullscreen_messages.dart';
import '../widgets/fullscreen_reaction_bar.dart';
import '../widgets/presence_notices.dart';
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
          PresenceNotices(stream: watch.presenceNotices),

          // "X is writing…" floats over the video while the messages panel is
          // closed (the open panel shows its own indicator).
          BlocBuilder<FullscreenUiCubit, FullscreenUiState>(
            buildWhen: (a, b) =>
                a.messagesOpen != b.messagesOpen ||
                a.bookmarksOpen != b.bookmarksOpen,
            builder: (context, state) =>
                state.messagesOpen || state.bookmarksOpen
                    ? const SizedBox.shrink()
                    : const _FloatingTyping(),
          ),

          // Drawings render over the video (pointer-transparent); the canvas
          // above captures touches only while draw mode is on. Both sit *under*
          // the control stack below, so its buttons (incl. the draw toggle to
          // exit) stay tappable.
          DrawingOverlay(stream: watch.drawings),
          const DrawingCanvas(),

          // Top-start: two independent toggle buttons stacked vertically — the
          // emoji button **above** the control-stack button. Each opens its
          // panel *beside* itself (rightward in LTR, leftward in Arabic/RTL).
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: BlocBuilder<FullscreenUiCubit, FullscreenUiState>(
                  builder: (context, state) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Emoji button (separate, on top) — opens the emoji
                        // strip beside it.
                        _SideToggle(
                          expanded: state.reactionsExpanded,
                          collapsedIcon: Icons.add_reaction_outlined,
                          onTap: ui.toggleReactions,
                          panel: const FullscreenReactionBar(),
                        ),
                        const SizedBox(height: 10),
                        // Control-stack button — opens messages / mic / draw /
                        // lock *underneath* it.
                        _SideToggle(
                          expanded: state.controlsExpanded,
                          collapsedIcon: Icons.tune_rounded,
                          onTap: ui.toggleControls,
                          below: true,
                          panel: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FullscreenMessagesButton(
                                open: state.messagesOpen,
                                onTap: ui.toggleMessages,
                              ),
                              const SizedBox(height: 10),
                              const FullscreenVoiceButton(),
const SizedBox(height: 10),
FullscreenBookmarkButton(
  open: state.bookmarksOpen,
  onTap: ui.toggleBookmarks,
),
const SizedBox(height: 10),
                              const FullscreenDrawButton(),
                              const SizedBox(height: 10),
                              const FullscreenLockButton(),
                            ],
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

          // The bookmarks side panel slides in from the right when open.
          BlocBuilder<FullscreenUiCubit, FullscreenUiState>(
            buildWhen: (a, b) => a.bookmarksOpen != b.bookmarksOpen,
            builder: (context, state) => FullscreenBookmarksPanel(
              open: state.bookmarksOpen,
              onClose: ui.closeBookmarks,
            ),
          ),
        ],
      ),
    );
  }
}

/// "X is writing…" as a translucent pill at the bottom-left of the fullscreen
/// video, mirroring the floating chat. Pointer-transparent and self-hides when
/// nobody is typing.
class _FloatingTyping extends StatelessWidget {
  const _FloatingTyping();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 44),
            child: BlocBuilder<WatchCubit, WatchState>(
              buildWhen: (a, b) => a.typingUsers != b.typingUsers,
              builder: (context, state) {
                final names =
                    state.typingUsers.values.where((n) => n.trim().isNotEmpty).toList();
                if (names.isEmpty) return const SizedBox.shrink();
                final label = '${names.join(', ')} ${context.tr(TranslationKeys.writing)}';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// A round toggle button with a panel that opens while [expanded]. By default
/// the panel opens *beside* the button (rightward in LTR, leftward in Arabic/
/// RTL); with [below] true it opens *underneath* instead. Used for the two
/// stacked fullscreen buttons — the emoji button (beside) and the control-stack
/// button (below). Fills in (primary tint) and swaps to a close icon while open.
class _SideToggle extends StatelessWidget {
  const _SideToggle({
    required this.expanded,
    required this.collapsedIcon,
    required this.onTap,
    required this.panel,
    this.below = false,
  });

  final bool expanded;
  final IconData collapsedIcon;
  final VoidCallback onTap;
  final Widget panel;

  /// Open the panel below the button (vertical) instead of beside it.
  final bool below;

  @override
  Widget build(BuildContext context) {
    final button = Material(
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
            expanded ? Icons.close_rounded : collapsedIcon,
            size: 22,
            color: Colors.white,
          ),
        ),
      ),
    );

    final reveal = AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: AlignmentDirectional.topStart,
      child: !expanded
          ? const SizedBox.shrink()
          : Padding(
              padding: below
                  ? const EdgeInsets.only(top: 10)
                  : const EdgeInsetsDirectional.only(start: 10),
              child: panel,
            ),
    );

    final children = [button, reveal];
    return below
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
  }
}
