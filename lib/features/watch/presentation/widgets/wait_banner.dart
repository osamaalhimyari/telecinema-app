import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

/// The "waiting for slow viewers" bar shown while the room's buffer gate holds
/// playback paused for someone who is loading.
class WaitBanner extends StatelessWidget {
  const WaitBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) => a.waiting != b.waiting,
      builder: (context, state) {
        if (!state.someoneWaiting) return const SizedBox.shrink();
        final names = state.waiting.map((u) => u.name).join(', ');
        return Container(
          width: double.infinity,
          color: context.semantic.warning.withValues(alpha: 0.16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: context.semantic.warning),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${context.tr(TranslationKeys.waitingForViewers)}${names.isEmpty ? '' : ' ($names)'}',
                  style: context.text.bodyMedium?.copyWith(color: context.semantic.warning),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
