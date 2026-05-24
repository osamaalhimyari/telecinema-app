import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/voice/voice_cubit.dart';
import '../bloc/voice/voice_state.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

/// The list of people currently in the room, with a "talking" indicator when
/// they are transmitting voice.
class ViewersPanel extends StatelessWidget {
  const ViewersPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) => a.presence != b.presence || a.waiting != b.waiting,
      builder: (context, state) {
        if (state.presence.isEmpty) {
          return Center(child: Text(context.tr(TranslationKeys.noOneWatching), style: context.text.bodyMedium));
        }
        return BlocBuilder<VoiceCubit, VoiceState>(
          builder: (context, voice) {
            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.presence.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final user = state.presence[i];
                final talking = voice.speakers.containsKey(user.id);
                final waiting = state.waiting.any((w) => w.id == user.id);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: context.colors.primary.withValues(alpha: 0.15),
                    child: Text(
                      user.name.isNotEmpty ? user.name.characters.first.toUpperCase() : '?',
                      style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(user.name, style: context.text.bodyLarge),
                  trailing: talking
                      ? Icon(Icons.mic_rounded, color: context.semantic.success, size: 20)
                      : waiting
                          ? Icon(Icons.hourglass_top_rounded, color: context.semantic.warning, size: 20)
                          : null,
                );
              },
            );
          },
        );
      },
    );
  }
}
