import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../domain/entities/playback_sync.dart';
import '../../../domain/entities/subtitle_settings.dart';
import 'subtitle_cue.dart';

/// Renders subtitle cues on top of an external (embed) room. Cross-origin
/// iframes can't host a `<track>`, so — exactly like the website — we fetch the
/// stored .srt/.vtt ourselves and display the active cue against the room's
/// virtual playhead (extrapolated from the last sync).
class SubtitleOverlay extends StatefulWidget {
  const SubtitleOverlay({
    super.key,
    required this.subtitleUrl,
    required this.lastSync,
    required this.settings,
  });

  final String subtitleUrl;
  final PlaybackSync? lastSync;

  /// The room's shared subtitle settings — timing offset shifts the active cue,
  /// weight/size style the text.
  final SubtitleSettings settings;

  @override
  State<SubtitleOverlay> createState() => _SubtitleOverlayState();
}

class _SubtitleOverlayState extends State<SubtitleOverlay> {
  List<SubtitleCue> _cues = const [];
  Timer? _ticker;
  String _current = '';

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  @override
  void didUpdateWidget(SubtitleOverlay old) {
    super.didUpdateWidget(old);
    if (old.subtitleUrl != widget.subtitleUrl) _load();
    // A new timing offset can change which cue is active right now — refresh
    // immediately instead of waiting for the next tick.
    if (old.settings.offset != widget.settings.offset) _tick();
  }

  Future<void> _load() async {
    try {
      final res = await http.get(Uri.parse(widget.subtitleUrl));
      if (res.statusCode == 200 && mounted) {
        // Decode the bytes as UTF-8 explicitly: `http`'s `.body` falls back to
        // latin-1 when the server omits a charset, which garbles Arabic (and
        // any other non-Latin) text. The server stores subtitles as UTF-8.
        final text = utf8.decode(res.bodyBytes, allowMalformed: true);
        setState(() => _cues = SubtitleParser.parse(text));
      }
    } catch (_) {
      /* subtitle unavailable — overlay stays empty */
    }
  }

  void _tick() {
    final sync = widget.lastSync;
    if (sync == null || _cues.isEmpty) return;
    // Positive offset shows cues later, so look up the cue that played
    // `offset` seconds earlier in the file.
    final t = sync.effectiveTime() - widget.settings.offset;
    final cue = _cues.firstWhere(
      (c) => c.contains(t),
      orElse: () => const SubtitleCue(start: -1, end: -1, text: ''),
    );
    if (cue.text != _current && mounted) setState(() => _current = cue.text);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_current.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 28, left: 16, right: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            _current,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.settings.size.toDouble(),
              height: 1.3,
              fontWeight: widget.settings.fontWeight,
            ),
          ),
        ),
      ),
    );
  }
}
