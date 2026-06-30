import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '/core/config/app_config.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/features/watch/presentation/pages/room_page.dart';
import '/injections/injection.dart';
import '../../domain/entities/tv_channel.dart';
import '../bloc/tv_launch/tv_launch_cubit.dart';
import '../bloc/tv_launch/tv_launch_state.dart';

/// A single-user preview of a live-TV [channel] before committing to a synced
/// room. Plays the channel through the server's stateless preview relay
/// (`/livetv/preview`), so — like a real `tv` room — the device never touches
/// the channel's origin. "Watch together" hands the same channel to
/// [TvLaunchCubit], which creates the synced room and opens it.
///
/// [path] is the channel's name-path in the provider tree, carried so a launched
/// room can re-resolve a fresh stream token later.
class TvPreviewPage extends StatelessWidget {
  const TvPreviewPage({super.key, required this.channel, required this.path});

  final TvChannel channel;
  final List<String> path;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TvLaunchCubit>(
      create: (_) => sl<TvLaunchCubit>(),
      child: _TvPreviewView(channel: channel, path: path),
    );
  }
}

class _TvPreviewView extends StatefulWidget {
  const _TvPreviewView({required this.channel, required this.path});

  final TvChannel channel;
  final List<String> path;

  @override
  State<_TvPreviewView> createState() => _TvPreviewViewState();
}

class _TvPreviewViewState extends State<_TvPreviewView> {
  final Player _player = Player(
    configuration: const PlayerConfiguration(bufferSize: 32 * 1024 * 1024),
  );
  late final VideoController _controller = VideoController(_player);

  bool _ready = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final url = AppConfig.tvPreviewUrl(url: widget.channel.url, headers: widget.channel.headers);
    if (url == null) {
      setState(() => _error = true);
      return;
    }

    _tune();
    // Forward progress proves the stream is healthy; clears a transient error.
    _player.stream.position.listen((p) {
      if (p > Duration.zero && mounted && (!_ready || _error)) {
        setState(() {
          _ready = true;
          _error = false;
        });
      }
    });
    _player.stream.error.listen((_) {
      if (mounted && !_ready) setState(() => _error = true);
    });

    try {
      await _player.open(Media(url));
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  /// Decode on the GPU when safe so heavy codecs play smoothly (mirrors the room
  /// player); silently ignored on backends without a native player.
  Future<void> _tune() async {
    final platform = _player.platform;
    if (platform is! NativePlayer) return;
    try {
      await platform.setProperty('hwdec', 'auto-safe');
    } catch (_) {
      /* property unsupported on this backend — ignore */
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// Creates the synced room for this channel and replaces the preview with it,
  /// so leaving the room returns to the channel list (not back to the preview).
  Future<void> _watchTogether() async {
    final cubit = context.read<TvLaunchCubit>();
    final room = await cubit.launch(channel: widget.channel, path: widget.path);
    if (room == null || !mounted) return;
    await _player.pause();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(builder: (_) => RoomPage(slug: room.slug, initialRoom: room)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: BlocListener<TvLaunchCubit, TvLaunchState>(
        listenWhen: (a, b) => b.errorKey != null && a.errorKey != b.errorKey,
        listener: (context, state) {
          if (state.errorKey != null) context.showSnack(context.tr(state.errorKey!));
        },
        child: Column(
          children: [
            Expanded(
              child: ColoredBox(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Video(controller: _controller, controls: NoVideoControls, fit: BoxFit.contain),
                    if (_error)
                      _Message(
                        icon: Icons.videocam_off_rounded,
                        text: context.tr(TranslationKeys.tvChannelUnavailable),
                      )
                    else if (!_ready)
                      const Center(child: CircularProgressIndicator()),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _LiveBadge(label: context.tr(TranslationKeys.tvLive)),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: BlocBuilder<TvLaunchCubit, TvLaunchState>(
                  buildWhen: (a, b) => a.busy != b.busy,
                  builder: (context, state) => SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: state.busy ? null : _watchTogether,
                      icon: state.busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.groups_rounded),
                      label: Text(context.tr(TranslationKeys.tvWatchTogether)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small red "LIVE" pill over the preview video.
class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.shade600,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white54, size: 44),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
