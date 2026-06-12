import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/status_view.dart';
import '/injections/injection.dart';
import '/routes/routes_names.dart';
import '../../data/cache_manager.dart';
import '../../domain/entities/cached_video.dart';

/// Library of videos cached on this device: see what's downloaded or in
/// progress, resume/pause, and delete to free space. Opened from the home
/// AppBar's "Cached videos" action.
class CachedVideosPage extends StatelessWidget {
  const CachedVideosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cache = sl<CacheManager>();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(TranslationKeys.cachedVideos)),
        actions: [
          StreamBuilder<List<CachedVideo>>(
            stream: cache.changes,
            initialData: cache.list(),
            builder: (context, snapshot) {
              final items = snapshot.data ?? const [];
              if (items.isEmpty) return const SizedBox.shrink();
              return IconButton(
                tooltip: context.tr(TranslationKeys.deleteAll),
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () => _confirmDeleteAll(context, cache),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<CachedVideo>>(
        stream: cache.changes,
        initialData: cache.list(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return StatusView(
              icon: Icons.download_for_offline_outlined,
              title: context.tr(TranslationKeys.cachedVideosEmpty),
              message: context.tr(TranslationKeys.cachedVideosEmptyHint),
            );
          }
          return Column(
            children: [
              _StorageHeader(items: items),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _CacheTile(item: items[i], cache: cache),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context, CacheManager cache) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr(TranslationKeys.deleteAll)),
        content: Text(ctx.tr(TranslationKeys.deleteAllConfirm)),
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
    if (ok == true) await cache.deleteAll();
  }
}

class _StorageHeader extends StatelessWidget {
  const _StorageHeader({required this.items});
  final List<CachedVideo> items;

  @override
  Widget build(BuildContext context) {
    final used = items.fold<int>(0, (sum, v) => sum + v.downloadedBytes);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Icon(Icons.sd_storage_outlined, size: 18, color: context.colors.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '${context.tr(TranslationKeys.storageUsed)}: ${humanBytes(used)}',
            style: context.text.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _CacheTile extends StatelessWidget {
  const _CacheTile({required this.item, required this.cache});
  final CachedVideo item;
  final CacheManager cache;

  @override
  Widget build(BuildContext context) {
    final pct = item.progress;
    return ListTile(
      leading: _leading(context),
      title: Text(item.title.isEmpty ? item.slug : item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(_subtitle(context), style: context.text.bodySmall),
          if (item.status == CacheStatus.downloading || item.status == CacheStatus.paused) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: pct, minHeight: 4),
            ),
          ],
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._actionButtons(context),
          IconButton(
            tooltip: context.tr(TranslationKeys.deleteDownload),
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      onTap: item.status == CacheStatus.done
          ? () => context.pushNamed(RoutesNames.room, pathParameters: {'slug': item.slug})
          : null,
    );
  }

  Widget _leading(BuildContext context) {
    final (icon, color) = switch (item.status) {
      CacheStatus.done => (Icons.download_done_rounded, context.colors.primary),
      CacheStatus.downloading => (Icons.downloading_rounded, context.colors.primary),
      CacheStatus.queued => (Icons.schedule_rounded, context.colors.onSurfaceVariant),
      CacheStatus.paused => (Icons.pause_circle_outline_rounded, context.colors.onSurfaceVariant),
      CacheStatus.error => (Icons.error_outline_rounded, context.colors.error),
    };
    return Icon(icon, color: color);
  }

  String _subtitle(BuildContext context) {
    switch (item.status) {
      case CacheStatus.done:
        return '${context.tr(TranslationKeys.savedOffline)} · ${humanBytes(item.downloadedBytes)}';
      case CacheStatus.error:
        return context.tr(TranslationKeys.downloadFailed);
      case CacheStatus.paused:
        return '${context.tr(TranslationKeys.downloadPaused)} · ${_progressText()}';
      case CacheStatus.queued:
      case CacheStatus.downloading:
        return _progressText();
    }
  }

  String _progressText() {
    final pct = item.progress;
    final pctText = pct != null ? ' (${(pct * 100).round()}%)' : '';
    final total = item.totalBytes > 0 ? ' / ${humanBytes(item.totalBytes)}' : '';
    return '${humanBytes(item.downloadedBytes)}$total$pctText';
  }

  List<Widget> _actionButtons(BuildContext context) {
    switch (item.status) {
      case CacheStatus.downloading:
      case CacheStatus.queued:
        return [
          IconButton(
            tooltip: context.tr(TranslationKeys.pause),
            icon: const Icon(Icons.pause_rounded),
            onPressed: () => cache.pause(item.key),
          ),
        ];
      case CacheStatus.paused:
      case CacheStatus.error:
        return [
          IconButton(
            tooltip: context.tr(TranslationKeys.resume),
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: () => cache.resume(item.key),
          ),
        ];
      case CacheStatus.done:
        return const [];
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
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
    if (ok == true) await cache.delete(item.key);
  }
}

/// Human-readable byte size (e.g. `1.4 GB`).
String humanBytes(int bytes) {
  if (bytes <= 0) return '0 MB';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  final decimals = (value >= 10 || unit == 0) ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${units[unit]}';
}
