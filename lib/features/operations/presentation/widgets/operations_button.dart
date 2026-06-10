import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../bloc/operations_cubit.dart';
import '../bloc/operations_state.dart';
import '../../domain/entities/server_operation.dart';

/// App-bar button that surfaces this device's server transfers. Shows a badge
/// with the active count and opens the operations sheet on tap. Hidden entirely
/// when there's nothing to show, so it stays out of the way until needed.
class OperationsButton extends StatelessWidget {
  const OperationsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OperationsCubit, OperationsState>(
      builder: (context, state) {
        if (!state.hasAny) return const SizedBox.shrink();
        final active = state.activeCount;
        return IconButton(
          tooltip: context.tr(TranslationKeys.operationsTitle),
          onPressed: () => _showSheet(context),
          icon: Badge(
            isLabelVisible: active > 0,
            label: Text('$active'),
            child: Icon(active > 0 ? Icons.sync_rounded : Icons.cloud_done_outlined),
          ),
        );
      },
    );
  }

  void _showSheet(BuildContext context) {
    final cubit = context.read<OperationsCubit>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: const _OperationsSheet(),
      ),
    );
  }
}

class _OperationsSheet extends StatelessWidget {
  const _OperationsSheet();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OperationsCubit, OperationsState>(
      builder: (context, state) {
        final ops = state.operations;
        final hasFinished = ops.any((o) => !o.isActive);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr(TranslationKeys.operationsTitle),
                        style: context.text.titleMedium,
                      ),
                    ),
                    if (hasFinished)
                      TextButton(
                        onPressed: () => context.read<OperationsCubit>().clearFinished(),
                        child: Text(context.tr(TranslationKeys.operationsClearFinished)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (ops.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      context.tr(TranslationKeys.operationsEmpty),
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      itemCount: ops.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (_, i) => _OperationTile(op: ops[i]),
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

class _OperationTile extends StatelessWidget {
  const _OperationTile({required this.op});

  final ServerOperation op;

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (op.status) {
      OperationStatus.error => context.tr(op.error ?? TranslationKeys.errorUnknown),
      OperationStatus.done => context.tr(TranslationKeys.operationDone),
      OperationStatus.downloading => _progressLabel(context),
    };
    final color = switch (op.status) {
      OperationStatus.error => context.colors.error,
      OperationStatus.done => context.colors.primary,
      OperationStatus.downloading => context.colors.onSurfaceVariant,
    };

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      dense: true,
      leading: Icon(_kindIcon(op.kind), color: context.colors.primary),
      title: Text(
        op.name.isEmpty ? context.tr(_kindLabel(op.kind)) : op.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          if (op.isActive)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: op.fraction, // null → indeterminate
                minHeight: 4,
                backgroundColor: context.colors.surfaceContainerHighest,
              ),
            ),
          const SizedBox(height: 4),
          Text(subtitle, style: context.text.bodySmall?.copyWith(color: color)),
        ],
      ),
      trailing: op.isActive
          ? IconButton(
              tooltip: context.tr(TranslationKeys.cancel),
              icon: const Icon(Icons.cancel_outlined),
              onPressed: () => context.read<OperationsCubit>().cancel(op),
            )
          : IconButton(
              tooltip: context.tr(TranslationKeys.close),
              icon: const Icon(Icons.close_rounded),
              onPressed: () => context.read<OperationsCubit>().dismiss(op),
            ),
    );
  }

  String _progressLabel(BuildContext context) {
    final kind = context.tr(_kindLabel(op.kind));
    if (op.percent != null) return '$kind · ${op.percent}%';
    if (op.bytesDownloaded > 0) return '$kind · ${_fmtBytes(op.bytesDownloaded)}';
    return kind;
  }

  static String _kindLabel(OperationKind kind) => switch (kind) {
    OperationKind.download => TranslationKeys.operationKindDownload,
    OperationKind.magnetDownload => TranslationKeys.operationKindMagnet,
    OperationKind.torrent => TranslationKeys.operationKindTorrent,
    OperationKind.upload => TranslationKeys.operationKindUpload,
  };

  static IconData _kindIcon(OperationKind kind) => switch (kind) {
    OperationKind.download => Icons.cloud_download_outlined,
    OperationKind.magnetDownload => Icons.cloud_download_outlined,
    OperationKind.torrent => Icons.downloading_rounded,
    OperationKind.upload => Icons.cloud_upload_outlined,
  };

  static String _fmtBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    const units = ['KB', 'MB', 'GB', 'TB'];
    double size = bytes / 1024;
    var i = 0;
    while (size >= 1024 && i < units.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[i]}';
  }
}
