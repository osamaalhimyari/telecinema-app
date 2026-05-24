import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../domain/entities/playback_sync.dart';
import 'subtitle_cue.dart';

/// Renders subtitle cues on top of an external (embed) room. Cross-origin
/// iframes can't host a `<track>`, so — exactly like the website — we fetch the
/// stored .srt/.vtt ourselves and display the active cue against the room's
/// virtual playhead (extrapolated from the last sync).
class SubtitleOverlay extends StatefulWidget {
  const SubtitleOverlay({super.key, required this.subtitleUrl, required this.lastSync});

  final String subtitleUrl;
  final PlaybackSync? lastSync;

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
  }

  Future<void> _load() async {
    try {
      final res = await http.get(Uri.parse(widget.subtitleUrl));
      if (res.statusCode == 200 && mounted) {
        setState(() => _cues = SubtitleParser.parse(res.body));
      }
    } catch (_) {
      /* subtitle unavailable — overlay stays empty */
    }
  }

  void _tick() {
    final sync = widget.lastSync;
    if (sync == null || _cues.isEmpty) return;
    final t = sync.effectiveTime();
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
