import 'dart:async';

import 'package:flutter/material.dart';

import '/core/errors/exceptions.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../../data/datasources/youtube_remote_datasource.dart';
import '../../domain/entities/youtube_stream_option.dart';

/// Resolves a pasted YouTube link to its direct download URLs **on-device** and
/// lets the viewer pick a quality — the shared entry point for both the Create
/// Room "YouTube" tab and the YouTube search flow.
///
/// Returns the chosen [YoutubeStreamOption] (whose `videoUrl`/`audioUrl` are the
/// real googlevideo CDN links the server then downloads + muxes), or null if the
/// resolve failed or the viewer cancelled. Self-contained: it owns the spinner,
/// the failure snack and the quality dialog, so the rooms feature only has to
/// call this one function and submit a `download` room with the result.
Future<YoutubeStreamOption?> pickYoutubeStreams(
  BuildContext context,
  String watchUrl,
  YoutubeRemoteDataSource datasource,
) async {
  final options = await _withLoading(context, () => datasource.resolveStreams(watchUrl));
  if (options == null || options.isEmpty || !context.mounted) return null;

  // One quality → straight through; several → let the viewer choose.
  if (options.length == 1) return options.first;
  return _showQualityDialog(context, watchUrl, options);
}

/// Runs [task] behind a modal spinner; surfaces a snack and returns null on
/// error (twin of the topcinema / search-flow helper).
Future<T?> _withLoading<T>(BuildContext context, Future<T> Function() task) async {
  final future = task();
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    ),
  );
  try {
    final result = await future;
    if (context.mounted) Navigator.of(context).pop();
    return result;
  } on ServerException catch (e) {
    if (context.mounted) {
      Navigator.of(context).pop();
      context.showSnack(context.tr(e.message));
    }
    return null;
  } catch (_) {
    if (context.mounted) {
      Navigator.of(context).pop();
      context.showSnack(context.tr(TranslationKeys.youtubeUnavailable));
    }
    return null;
  }
}

/// Quality picker dialog — a twin of the topcinema / cinema ones, so every
/// direct-download flow looks identical.
Future<YoutubeStreamOption?> _showQualityDialog(
  BuildContext context,
  String heading,
  List<YoutubeStreamOption> options,
) {
  return showDialog<YoutubeStreamOption>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.tr(TranslationKeys.chooseQuality)),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              heading,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final o in options)
                    _qualityTile(dialogContext, o, () => Navigator.of(dialogContext).pop(o)),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.tr(TranslationKeys.cancel)),
        ),
      ],
    ),
  );
}

Widget _qualityTile(BuildContext context, YoutubeStreamOption o, VoidCallback onTap) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    clipBehavior: Clip.antiAlias,
    child: ListTile(
      leading: Container(
        width: 56,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          o.shortLabel,
          style: context.text.labelSmall?.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(o.label),
      subtitle: o.meta.isEmpty ? null : Text(o.meta),
      trailing: const Icon(Icons.download_rounded),
      onTap: onTap,
    ),
  );
}
