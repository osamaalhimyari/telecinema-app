import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

/// "X is writing…" line shown above a chat composer. Reads the room's live
/// [WatchState.typingUsers]; the cubit auto-expires each entry, so this can
/// never stay stuck after someone stops. [dark] styles it for the translucent
/// fullscreen panel.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key, this.dark = false});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) => a.typingUsers != b.typingUsers,
      builder: (context, state) {
        final names = state.typingUsers.values.where((n) => n.trim().isNotEmpty).toList();
        if (names.isEmpty) return const SizedBox.shrink();
        final label = '${names.join(', ')} ${context.tr(TranslationKeys.writing)}';
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelSmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: dark ? Colors.white70 : context.colors.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}
