import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '/core/errors/exceptions.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/routes/routes_names.dart';
import '../../data/datasources/youtube_remote_datasource.dart';
import '../../domain/entities/youtube_quality.dart';
import '../../domain/entities/youtube_video.dart';

/// Entry point for the ISOLATED YouTube "search → server download" flow.
///
/// Flow: preview the picked [video] in a real embedded YouTube player → on
/// "Create room", enumerate available qualities on-device → pick one → hand off
/// to the existing Create Room screen pre-filled with the watch URL + chosen
/// height, where the server downloads it (yt-dlp) and opens the room.
/// Self-contained: it talks only to [datasource] and navigates by route.
Future<void> startYoutubeRoomFlow(
  BuildContext context,
  YoutubeVideo video,
  YoutubeRemoteDataSource datasource,
) async {
  // A full-screen page (above the shell) hosts the player — far more reliable
  // for the underlying platform-view than a clipped bottom sheet.
  final proceed = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(builder: (_) => _PreviewPage(video: video), fullscreenDialog: true),
  );
  if (proceed != true || !context.mounted) return;

  final qualities = await _withLoading(context, () => datasource.qualities(video.id));
  if (qualities == null || qualities.isEmpty || !context.mounted) return;

  final quality = await _showQualityDialog(context, video.title, qualities);
  if (quality == null || !context.mounted) return;

  // Hand off to the existing Create Room screen with the watch URL in the
  // download field + the chosen max height, so the user can review the name /
  // password / category before creating. That screen owns the download + room.
  context.pushNamed(
    RoutesNames.createRoom,
    extra: {
      'name': video.title,
      'videoUrl': video.url,
      'maxHeight': quality.height,
    },
  );
}

/// Runs [task] behind a modal spinner; surfaces a snack and returns null on
/// error (mirrors the topcinema picker's helper).
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

/// Embedded-player preview with a "Create room" call to action. This is
/// preview-only — the synchronized playback happens later in the room.
class _PreviewPage extends StatefulWidget {
  const _PreviewPage({required this.video});

  final YoutubeVideo video;

  @override
  State<_PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<_PreviewPage> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.video.id,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showFullscreenButton: false,
        playsInline: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        children: [
          YoutubePlayer(controller: _controller, aspectRatio: 16 / 9),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.video.title, style: context.text.titleMedium),
                const SizedBox(height: 4),
                Text(
                  widget.video.author,
                  style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.movie_creation_outlined),
              label: Text(context.tr(TranslationKeys.youtubeCreateRoom)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Quality picker dialog — a twin of the topcinema one, so the two
/// direct-download flows look identical.
Future<YoutubeQuality?> _showQualityDialog(
  BuildContext context,
  String heading,
  List<YoutubeQuality> qualities,
) {
  return showDialog<YoutubeQuality>(
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
                  for (final q in qualities)
                    _qualityTile(dialogContext, q, () => Navigator.of(dialogContext).pop(q)),
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

Widget _qualityTile(BuildContext context, YoutubeQuality q, VoidCallback onTap) {
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
          q.shortLabel,
          style: context.text.labelSmall?.copyWith(
            color: context.colors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(q.label),
      subtitle: q.meta.isEmpty ? null : Text(q.meta),
      trailing: const Icon(Icons.download_rounded),
      onTap: onTap,
    ),
  );
}
