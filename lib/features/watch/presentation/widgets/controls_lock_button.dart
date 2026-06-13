import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

/// Per-user touch lock toggle. Locking disables the video's tap layer and
/// playback controls (so a faulty screen's ghost-touches can't play/pause/seek)
/// while emoji, chat and the mic keep working. Local only — never synced.
///
/// [tooltip] resolves to "Lock screen touch" / "Unlock screen touch".
String _tooltip(BuildContext context, bool locked) => context.tr(
  locked ? TranslationKeys.unlockControls : TranslationKeys.lockControls,
);

/// Fullscreen variant — a 48×48 circle that matches [FullscreenVoiceButton], so
/// it stacks cleanly beneath the mic in the fullscreen control column.
class FullscreenLockButton extends StatelessWidget {
  const FullscreenLockButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) => a.controlsLocked != b.controlsLocked,
      builder: (context, state) {
        final locked = state.controlsLocked;
        return Tooltip(
          message: _tooltip(context, locked),
          child: GestureDetector(
            onTap: () => context.read<WatchCubit>().toggleControlsLock(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: locked
                    ? context.colors.primary.withValues(alpha: 0.9)
                    : Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                size: 20,
                color: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Portrait variant — a compact icon button for the in-room control row.
class ControlsLockButton extends StatelessWidget {
  const ControlsLockButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) => a.controlsLocked != b.controlsLocked,
      builder: (context, state) {
        final locked = state.controlsLocked;
        return IconButton(
          tooltip: _tooltip(context, locked),
          isSelected: locked,
          onPressed: () => context.read<WatchCubit>().toggleControlsLock(),
          icon: Icon(locked ? Icons.lock_rounded : Icons.lock_open_rounded),
          color: locked ? context.colors.primary : null,
        );
      },
    );
  }
}
