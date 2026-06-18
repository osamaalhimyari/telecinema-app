import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/routes/routes_names.dart';
import '../../data/datasources/youtube_remote_datasource.dart';
import '../../domain/entities/youtube_video.dart';

/// Entry point for the ISOLATED YouTube "search → server download" flow.
///
/// Flow: preview the picked [video] in a real embedded YouTube player → on
/// "Create room", hand the watch URL to the existing Create Room screen's
/// YouTube tab, which resolves the direct download links ON-DEVICE, lets the
/// viewer pick a quality, and submits them as a `download` room the server
/// downloads + muxes (no server-side yt-dlp — its IP is bot-blocked by YouTube).
/// Self-contained: it talks only to [datasource] (for the search page) and
/// navigates by route, never touching the rooms feature's internals.
Future<void> startYoutubeRoomFlow(
  BuildContext context,
  YoutubeVideo video,
  // Kept for call-site compatibility (the search page already holds it); the
  // on-device resolve now happens in the Create Room YouTube tab on submit.
  YoutubeRemoteDataSource datasource,
) async {
  // A full-screen page (above the shell) hosts the player — far more reliable
  // for the underlying platform-view than a clipped bottom sheet.
  final proceed = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(builder: (_) => _PreviewPage(video: video), fullscreenDialog: true),
  );
  if (proceed != true || !context.mounted) return;

  // Hand off to the Create Room YouTube tab with the watch URL prefilled, so the
  // user can review name / password / category before the on-device resolve +
  // quality pick that runs when they tap Create.
  context.pushNamed(
    RoutesNames.createRoom,
    extra: {
      'name': video.title,
      'youtubeUrl': video.url,
      'thumbnail': video.thumbnailUrl,
    },
  );
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
