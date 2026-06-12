import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/features/rooms/domain/entities/room.dart';
import '/features/watch/presentation/bloc/watch_cubit.dart';
import '/injections/injection.dart';
import '../../data/cache_manager.dart';
import '../../domain/entities/cached_video.dart';

/// Compact in-room control to cache the current room's video to this device.
///
/// Tap cycles through download → pause → resume; long-press deletes. While
/// downloading it shows a progress ring; once finished it shows a "saved"
/// badge. Hidden for room types that can't be cached (embed rooms, web).
class DownloadButton extends StatelessWidget {
  const DownloadButton({super.key});

  @override
  Widget build(BuildContext context) {
    final room = context.select<WatchCubit, Room?>((c) => c.state.room);
    if (room == null) return const SizedBox.shrink();
    final cache = sl<CacheManager>();
    if (!cache.canCache(room)) return const SizedBox.shrink();

    return StreamBuilder<CachedVideo?>(
      stream: cache.watch(room.slug),
      initialData: cache.get(room.slug),
      builder: (context, snapshot) {
        final item = snapshot.data;
        final status = item?.status;

        final tooltip = switch (status) {
          CacheStatus.done => context.tr(TranslationKeys.savedOffline),
          CacheStatus.downloading || CacheStatus.queued => context.tr(TranslationKeys.pause),
          CacheStatus.paused => context.tr(TranslationKeys.resume),
          CacheStatus.error => context.tr(TranslationKeys.downloadFailed),
          null => context.tr(TranslationKeys.downloadForOffline),
        };

        void onTap() {
          switch (status) {
            case null:
            case CacheStatus.error:
              cache.start(room);
            case CacheStatus.downloading:
            case CacheStatus.queued:
              cache.pause(room.slug);
            case CacheStatus.paused:
              cache.resume(room.slug);
            case CacheStatus.done:
              context.showSnack(context.tr(TranslationKeys.savedOffline));
          }
        }

        return Tooltip(
          message: tooltip,
          child: InkResponse(
            radius: 24,
            onTap: onTap,
            onLongPress: item == null ? null : () => _confirmDelete(context, cache, room.slug),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(child: _visual(context, status, item?.progress)),
            ),
          ),
        );
      },
    );
  }

  Widget _visual(BuildContext context, CacheStatus? status, double? progress) {
    switch (status) {
      case CacheStatus.done:
        return Icon(Icons.download_done_rounded, color: context.colors.primary);
      case CacheStatus.downloading:
      case CacheStatus.queued:
        return _ring(context, progress, Icons.pause_rounded);
      case CacheStatus.paused:
        return _ring(context, progress, Icons.file_download_outlined, dim: true);
      case CacheStatus.error:
        return Icon(Icons.error_outline_rounded, color: context.colors.error);
      case null:
        return Icon(
          Icons.download_for_offline_outlined,
          color: context.colors.onSurfaceVariant,
        );
    }
  }

  Widget _ring(BuildContext context, double? progress, IconData icon, {bool dim = false}) {
    final color = dim ? context.colors.onSurfaceVariant : context.colors.primary;
    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(value: progress, strokeWidth: 2.4, color: color),
          ),
          Icon(icon, size: 14, color: color),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, CacheManager cache, String slug) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr(TranslationKeys.deleteDownload)),
        content: Text(ctx.tr(TranslationKeys.deleteDownloadConfirm)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(ctx.tr(TranslationKeys.cancel))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.tr(TranslationKeys.delete)),
          ),
        ],
      ),
    );
    if (ok == true) await cache.delete(slug);
  }
}
