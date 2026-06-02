import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import 'socket_cubit.dart';
import 'socket_state.dart';

/// A small pill that reflects the live connection status. Reads the global
/// [SocketCubit] singleton, so it can be dropped into any header.
class SocketStatusIndicator extends StatelessWidget {
  const SocketStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SocketCubit, SocketState>(
      builder: (context, state) {
        final (color, labelKey, dotColor) = switch (state.status) {
          SocketStatus.connected => (context.semantic.success, TranslationKeys.live, context.semantic.success),
          SocketStatus.connecting => (context.semantic.warning, TranslationKeys.connecting, context.semantic.warning),
          SocketStatus.error => (context.colors.error, TranslationKeys.reconnecting, context.colors.error),
          SocketStatus.disconnected => (context.colors.error, TranslationKeys.disconnected, context.colors.error),
        };

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                context.tr(labelKey),
                style: context.text.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
