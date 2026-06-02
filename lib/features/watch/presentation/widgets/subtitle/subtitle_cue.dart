/// One subtitle line with its on-screen time window (in seconds).
class SubtitleCue {
  const SubtitleCue({required this.start, required this.end, required this.text});

  final double start;
  final double end;
  final String text;

  bool contains(double t) => t >= start && t <= end;
}

/// Minimal SRT/VTT parser. Both formats share the same cue structure; the only
/// differences we care about are the SRT `,` millisecond separator and the
/// optional `WEBVTT` header / cue identifiers, all of which are tolerated.
class SubtitleParser {
  SubtitleParser._();

  static List<SubtitleCue> parse(String content) {
    final cues = <SubtitleCue>[];
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) continue;

      // Find the timing line (`00:00:01,000 --> 00:00:04,000`).
      var timingIndex = lines.indexWhere((l) => l.contains('-->'));
      if (timingIndex == -1) continue;

      final timing = lines[timingIndex];
      final parts = timing.split('-->');
      if (parts.length != 2) continue;

      final start = _parseTimestamp(parts[0]);
      final end = _parseTimestamp(parts[1]);
      if (start == null || end == null) continue;

      final text = lines.sublist(timingIndex + 1).join('\n').trim();
      if (text.isEmpty) continue;
      cues.add(SubtitleCue(start: start, end: end, text: _stripTags(text)));
    }
    return cues;
  }

  /// `HH:MM:SS,mmm` or `MM:SS.mmm` → seconds.
  static double? _parseTimestamp(String raw) {
    final s = raw.trim().replaceAll(',', '.').split(' ').first;
    final segments = s.split(':');
    try {
      double seconds = 0;
      for (final seg in segments) {
        seconds = seconds * 60 + double.parse(seg);
      }
      return seconds;
    } catch (_) {
      return null;
    }
  }

  static String _stripTags(String text) => text.replaceAll(RegExp(r'<[^>]+>'), '');
}
