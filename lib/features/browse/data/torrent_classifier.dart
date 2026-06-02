/// Pure helpers that read meaning out of a torrent's release name so the UI can
/// group results. Series results carry an `SxxExx` (or `Season N`) marker;
/// movie results don't, so they're grouped by resolution instead and multi-film
/// bundles (trilogies, complete collections) are flagged as packs.
///
/// All matching is case-insensitive and tolerant of the usual `.`/`_`/`-`/space
/// separators that release groups sprinkle through names.
library;

/// `S05E06` → `(season: 5, episode: 6)`. Falls back to a season-only marker for
/// season packs (`S04.COMPLETE`, `Season 1`) and to `(null, null)` when neither
/// is present.
({int? season, int? episode}) parseSeasonEpisode(String name) {
  final ep = _episodeRe.firstMatch(name);
  if (ep != null) {
    return (season: int.tryParse(ep.group(1)!), episode: int.tryParse(ep.group(2)!));
  }
  // No episode → maybe a whole-season pack. `S04` (not followed by an episode)
  // or the spelled-out `Season 4`.
  final s = _seasonRe.firstMatch(name) ?? _seasonWordRe.firstMatch(name);
  if (s != null) return (season: int.tryParse(s.group(1)!), episode: null);
  return (season: null, episode: null);
}

/// A coarse resolution bucket used to group movie results: `4K`, `1080p`,
/// `720p`, `480p`, or `SD` when nothing matches.
String parseQuality(String name) {
  final l = name.toLowerCase();
  if (l.contains('2160p') || l.contains('4k') || l.contains('uhd')) return '4K';
  if (l.contains('1080p')) return '1080p';
  if (l.contains('720p')) return '720p';
  if (l.contains('480p')) return '480p';
  return 'SD';
}

/// True when the release bundles more than one film (a trilogy, quadrilogy,
/// boxset, "complete collection", …) rather than a single movie. Used to peel
/// collections into their own group in the movie picker.
bool isPackName(String name) {
  final l = name.toLowerCase();
  return _packHints.any(l.contains) || _multiFilmRe.hasMatch(l);
}

// `S05E06`, `s5e6`, `S05.E06`, `S05xE06` …
final RegExp _episodeRe =
    RegExp(r's(\d{1,2})[ ._-]?[ex](\d{1,2})', caseSensitive: false);

// A standalone `S04` token (whole-season pack). The episode form is handled
// above and returns early, so this only runs on names without an `SxxExx`; the
// word boundaries keep it from matching stray `s` + digits inside a release tag
// while still catching `.s05.` between resolution/year dots.
final RegExp _seasonRe = RegExp(r'\bs(\d{1,2})\b', caseSensitive: false);

// Spelled-out `Season 4` / `Season.4` / `Season_4`.
final RegExp _seasonWordRe =
    RegExp(r'season[ ._-]?(\d{1,2})', caseSensitive: false);

const List<String> _packHints = [
  'trilogy', 'quadrilogy', 'duology', 'pentalogy', 'anthology', 'saga',
  'collection', 'complete', 'boxset', 'box set', 'box.set',
  'ultimate matrix', 'movie collection', 'all movies',
];

// `1-4`, `1 to 4`, `1-3`, `5 movie`, `4 films` — numeric multi-film hints.
final RegExp _multiFilmRe =
    RegExp(r'\b\d\s*(?:-|to)\s*\d\b|\b\d+\s*(?:movies?|films?)\b');
