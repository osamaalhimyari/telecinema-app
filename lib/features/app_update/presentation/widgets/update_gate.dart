import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/app_update_cubit.dart';
import '../bloc/app_update_state.dart';

/// Wraps the whole app (via `MaterialApp.builder`). When the server marks an
/// update as *forced*, it paints a full-screen, non-dismissible blocker over
/// the app so the user can't continue until they update. Otherwise it's a
/// transparent pass-through.
class UpdateGate extends StatelessWidget {
  const UpdateGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppUpdateCubit, AppUpdateState>(
      buildWhen: (a, b) =>
          a.isForced != b.isForced ||
          a.status != b.status ||
          a.received != b.received ||
          a.errorKey != b.errorKey,
      builder: (context, state) {
        if (!state.isForced) return child;
        // Keep `child` mounted underneath so theme/locale stay alive, with an
        // opaque blocker on top that swallows all interaction.
        return Stack(
          children: [
            child,
            const Positioned.fill(child: _ForcedUpdateOverlay()),
          ],
        );
      },
    );
  }
}

class _ForcedUpdateOverlay extends StatelessWidget {
  const _ForcedUpdateOverlay();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: BlocBuilder<AppUpdateCubit, AppUpdateState>(
                builder: (context, state) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.system_update_rounded, size: 64, color: context.colors.primary),
                      const SizedBox(height: 20),
                      Text(
                        context.tr(TranslationKeys.updateRequiredTitle),
                        style: context.text.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        context.tr(TranslationKeys.updateRequiredBody),
                        style: context.text.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (state.info.versionName != null) ...[
                        const SizedBox(height: 6),
                        Text('v${state.info.versionName}', style: context.text.bodySmall),
                      ],
                      const SizedBox(height: 28),
                      _action(context, state),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _action(BuildContext context, AppUpdateState state) {
    final cubit = context.read<AppUpdateCubit>();

    if (state.isDownloading) {
      return Column(
        children: [
          LinearProgressIndicator(value: state.progress),
          const SizedBox(height: 12),
          Text(
            '${context.tr(TranslationKeys.updateDownloading)} ${state.percent ?? 0}%',
            style: context.text.bodySmall,
          ),
        ],
      );
    }

    final isError = state.status == UpdateStatus.error || state.errorKey != null;

    return Column(
      children: [
        if (isError && state.errorKey != null) ...[
          Text(
            context.tr(state.errorKey!),
            style: context.text.bodySmall?.copyWith(color: context.colors.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => cubit.start(),
            icon: Icon(state.isReady ? Icons.install_mobile_rounded : Icons.download_rounded),
            label: Text(
              context.tr(state.isReady ? TranslationKeys.updateInstall : TranslationKeys.updateDownload),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Sideloaded installs trigger Play Protect's "unsafe app" prompt.
        Text(
          context.tr(TranslationKeys.updateInstallHint),
          textAlign: TextAlign.center,
          style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
