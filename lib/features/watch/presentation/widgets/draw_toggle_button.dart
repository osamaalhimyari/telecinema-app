import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/draw_mode/draw_mode_cubit.dart';
import '../bloc/draw_mode/draw_mode_state.dart';

/// Fullscreen variant — a 38×38 circle that matches [FullscreenVoiceButton] /
/// [FullscreenLockButton], so it stacks cleanly in the fullscreen control
/// column. Toggles draw-on-video mode; fills in (primary tint) while active.
class FullscreenDrawButton extends StatelessWidget {
  const FullscreenDrawButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DrawModeCubit, DrawModeState>(
      buildWhen: (a, b) => a.active != b.active,
      builder: (context, state) {
        return Tooltip(
          message: context.tr(TranslationKeys.draw),
          child: GestureDetector(
            onTap: () => context.read<DrawModeCubit>().toggle(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: state.active
                    ? context.colors.primary.withValues(alpha: 0.9)
                    : Colors.black.withValues(alpha: 0.45),
                shape: BoxShape.circle,
              ),
              child: Icon(
                state.active ? Icons.brush_rounded : Icons.brush_outlined,
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
class DrawToggleButton extends StatelessWidget {
  const DrawToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DrawModeCubit, DrawModeState>(
      buildWhen: (a, b) => a.active != b.active,
      builder: (context, state) {
        return IconButton(
          tooltip: context.tr(TranslationKeys.draw),
          isSelected: state.active,
          onPressed: () => context.read<DrawModeCubit>().toggle(),
          icon: Icon(state.active ? Icons.brush_rounded : Icons.brush_outlined),
          color: state.active ? context.colors.primary : null,
        );
      },
    );
  }
}
