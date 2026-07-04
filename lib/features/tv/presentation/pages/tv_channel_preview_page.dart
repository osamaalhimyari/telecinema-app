import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/features/watch/presentation/pages/room_page.dart';
import '/injections/injection.dart';
import '../../domain/entities/tv_channel.dart';
import '../bloc/tv_launch/tv_launch_cubit.dart';
import '../bloc/tv_launch/tv_launch_state.dart';

/// A live preview of a single TV [channel] before committing to a room — same
/// idea as opening a movie's detail page before creating a room. The channel
/// origin is played on-device with its per-channel headers (no server relay);
/// "Create room" then turns it into a synced watch-party room via
/// [TvLaunchCubit], exactly like a movie hands off to Create Room.
///
/// [path] is the channel's name-path in the provider tree, carried so the
/// created room can re-resolve a fresh stream token when this one expires.
class TvChannelPreviewPage extends StatelessWidget {
  const TvChannelPreviewPage({super.key, required this.channel, this.path = const []});

  final TvChannel channel;
  final List<String> path;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TvLaunchCubit>(
      create: (_) => sl<TvLaunchCubit>(),
      child: _PreviewView(channel: channel, path: path),
    );
  }
}

class _PreviewView extends StatefulWidget {
  const _PreviewView({required this.channel, required this.path});

  final TvChannel channel;
  final List<String> path;

  @override
  State<_PreviewView> createState() => _PreviewViewState();
}

class _PreviewViewState extends State<_PreviewView> {
  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Play the channel origin directly with its mandatory per-channel headers.
    _player.stream.error.listen((_) {
      if (mounted) setState(() => _failed = true);
    });
    _open();
  }

  Future<void> _open() async {
    try {
      await _player.open(
        Media(widget.channel.url, httpHeaders: widget.channel.headers),
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _createRoom(BuildContext context) async {
    final cubit = context.read<TvLaunchCubit>();
    final room = await cubit.launch(channel: widget.channel, path: widget.path);
    if (room == null || !context.mounted) return;
    // Hand off to the room (which opens its own player), replacing the preview
    // so its player is torn down and we don't double-play the stream.
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(builder: (_) => RoomPage(slug: room.slug, initialRoom: room)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.channel.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: BlocListener<TvLaunchCubit, TvLaunchState>(
        listenWhen: (a, b) => b.errorKey != null && a.errorKey != b.errorKey,
        listener: (context, state) {
          if (state.errorKey != null) context.showSnack(context.tr(state.errorKey!));
        },
        child: Column(
          children: [
            // Live preview pane.
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: _failed
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.live_tv_outlined, color: Colors.white54, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              context.tr(TranslationKeys.tvPreviewFailed),
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Video(controller: _controller, controls: NoVideoControls),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.channel.name,
                style: context.text.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            const Spacer(),
            // Create-room action — mirrors the movie "create room" hand-off.
            SafeArea(
              minimum: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: BlocBuilder<TvLaunchCubit, TvLaunchState>(
                buildWhen: (a, b) => a.busy != b.busy,
                builder: (context, state) => FilledButton.icon(
                  onPressed: state.busy ? null : () => _createRoom(context),
                  icon: state.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.group_add_rounded),
                  label: Text(context.tr(TranslationKeys.tvCreateRoom)),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
