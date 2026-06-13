import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/unlock_overlay/unlock_overlay_cubit.dart';
import '../bloc/watch_cubit.dart';
import '../bloc/watch_state.dart';

/// Full-screen password gate for a protected room. Mirrors the website's
/// client-side unlock overlay.
class UnlockOverlay extends StatelessWidget {
  const UnlockOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UnlockOverlayCubit(),
      child: const _UnlockOverlayView(),
    );
  }
}

class _UnlockOverlayView extends StatelessWidget {
  const _UnlockOverlayView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WatchCubit, WatchState>(
      builder: (context, state) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 48, color: context.colors.primary),
                const SizedBox(height: 16),
                Text(
                  state.room?.name ?? '',
                  style: context.text.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr(TranslationKeys.enterPassword),
                  style: context.text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextField(
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.tr(TranslationKeys.password),
                    prefixIcon: const Icon(Icons.key_rounded),
                    errorText: state.unlockErrorKey == null
                        ? null
                        : context.tr(state.unlockErrorKey!),
                  ),
                  onChanged: (v) => context.read<UnlockOverlayCubit>().setPassword(v),
                  onSubmitted: (v) => context.read<WatchCubit>().unlock(v),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: state.unlockBusy
                        ? null
                        : () => context.read<WatchCubit>().unlock(
                            context.read<UnlockOverlayCubit>().state.password,
                          ),
                    child: state.unlockBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr(TranslationKeys.unlock)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
