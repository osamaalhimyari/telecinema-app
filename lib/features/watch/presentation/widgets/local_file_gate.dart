import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

/// Shown over the player of a `local` room when this device has no on-device
/// copy yet. The viewer picks their own copy of the same file (imported into the
/// cache, never uploaded), or — if the creator also uploaded it — streams online
/// instead. Playback still syncs over the socket; only the media is local.
class LocalFileGate extends StatelessWidget {
  const LocalFileGate({super.key});

  Future<void> _pick(BuildContext context) async {
    final file = await FilePicker.pickFile(type: FileType.video);
    final path = file?.path;
    if (path != null && context.mounted) {
      context.read<WatchCubit>().provideLocalFile(path, name: file!.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The on-device cache is native-only (disabled on web), so a local room
    // can't be supplied a file there — show a graceful message instead.
    if (kIsWeb) {
      return _Message(
        icon: Icons.desktop_access_disabled_rounded,
        text: context.tr(TranslationKeys.localRoomWebUnsupported),
      );
    }

    return BlocBuilder<WatchCubit, WatchState>(
      buildWhen: (a, b) =>
          a.importingLocal != b.importingLocal || a.room != b.room,
      builder: (context, state) {
        if (state.importingLocal) {
          return _Message(
            spinner: true,
            text: context.tr(TranslationKeys.preparingLocalFile),
          );
        }

        final room = state.room;
        final hasOnline = (room?.videoUrl ?? '').isNotEmpty;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.devices_rounded,
                  color: Colors.white70,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Text(
                  context.tr(TranslationKeys.localRoomTitle),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(TranslationKeys.localRoomInstruction),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => _pick(context),
                  icon: const Icon(Icons.video_library_outlined),
                  label: Text(context.tr(TranslationKeys.chooseFile)),
                ),
                if (hasOnline) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () =>
                        context.read<WatchCubit>().watchOnlineFallback(),
                    icon: const Icon(Icons.cloud_outlined, size: 18),
                    label: Text(context.tr(TranslationKeys.watchOnlineInstead)),
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Centered icon/spinner + caption, matching the player stage's message style.
class _Message extends StatelessWidget {
  const _Message({this.icon, this.text = '', this.spinner = false});

  final IconData? icon;
  final String text;
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinner)
            const CircularProgressIndicator()
          else if (icon != null)
            Icon(icon, color: Colors.white54, size: 40),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
