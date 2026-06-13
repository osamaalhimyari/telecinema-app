import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/app_update_cubit.dart';
import '../bloc/app_update_state.dart';

/// App-bar action that appears only when a newer build exists. Tapping it opens
/// a sheet with the release notes and an "Update now" button; while the APK
/// downloads it becomes a cancellable progress ring, and once ready it becomes
/// an "Install" button. Hidden entirely when the app is up to date.
class UpdateButton extends StatelessWidget {
  const UpdateButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppUpdateCubit, AppUpdateState>(
      builder: (context, state) {
        if (!state.hasUpdate) return const SizedBox.shrink();

        switch (state.status) {
          case UpdateStatus.downloading:
            return IconButton(
              tooltip: '${context.tr(TranslationKeys.updateDownloading)} ${state.percent ?? 0}%',
              onPressed: () => context.read<AppUpdateCubit>().cancelDownload(),
              icon: SizedBox(
                width: 22,
                height: 22,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(value: state.progress, strokeWidth: 2.4),
                    const Icon(Icons.close_rounded, size: 12),
                  ],
                ),
              ),
            );

          case UpdateStatus.readyToInstall:
          case UpdateStatus.installing:
            return IconButton(
              tooltip: context.tr(TranslationKeys.updateInstall),
              onPressed: () => context.read<AppUpdateCubit>().install(),
              icon: const Icon(Icons.install_mobile_rounded),
            );

          default:
            return IconButton(
              tooltip: context.tr(TranslationKeys.updateAvailable),
              onPressed: () => UpdateSheet.show(context),
              icon: const Badge(
                smallSize: 8,
                child: Icon(Icons.system_update_rounded),
              ),
            );
        }
      },
    );
  }
}

/// Bottom sheet with the new version's details and the "Update now" action.
class UpdateSheet extends StatelessWidget {
  const UpdateSheet._();

  static void show(BuildContext context) {
    final cubit = context.read<AppUpdateCubit>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(value: cubit, child: const UpdateSheet._()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppUpdateCubit, AppUpdateState>(
      builder: (context, state) {
        final info = state.info;
        final notes = info.releaseNotes?.trim();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.system_update_rounded, color: context.colors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr(TranslationKeys.updateAvailable),
                        style: context.text.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitle(context, state),
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Text(notes, style: context.text.bodyMedium),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      context.read<AppUpdateCubit>().start();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: Text(context.tr(TranslationKeys.updateDownload)),
                  ),
                ),
                const SizedBox(height: 10),
                // Sideloaded installs trigger Play Protect's "unsafe app" prompt —
                // tell the user how to get past it.
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 14, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        context.tr(TranslationKeys.updateInstallHint),
                        style: context.text.bodySmall
                            ?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                if (!state.isForced)
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.tr(TranslationKeys.updateLater)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _subtitle(BuildContext context, AppUpdateState state) {
    final version = state.info.versionName;
    final size = state.info.fileSize;
    final parts = <String>[
      if (version != null) 'v$version',
      if (size != null && size > 0) _fmtBytes(size),
    ];
    return parts.isEmpty ? context.tr(TranslationKeys.updateAvailable) : parts.join(' · ');
  }

  static String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB'];
    double size = bytes / 1024;
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[i]}';
  }
}
