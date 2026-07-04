/// Small, dependency-free JSON coercion helpers for the EgyBest payloads.
///
/// Kept local to the Cinema module (rather than importing Browse's `json_parse`)
/// so the feature stays fully self-contained. EgyBest is loosely typed —
/// numbers arrive as ints or strings, posters as `http://…`, genres in two
/// different shapes — so every accessor is defensive.
library;

/// Trimmed non-empty string, or null.
String? asString(dynamic v) {
  final s = v?.toString().trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Tolerant int (accepts `54262`, `"54262"`, `54262.0`); 0 when unparseable.
int asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString().trim() ?? '') ?? 0;
}

bool asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v?.toString().trim().toLowerCase();
  return s == '1' || s == 'true';
}

/// `vote_average` → short rating text (`8`, `7.29` → `7.3`), or null at 0.
String? asRating(dynamic v) {
  final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
  if (n == null || n <= 0) return null;
  final s = n.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// TMDB ships posters over plain `http://image.tmdb.org` — upgrade to https so
/// Android's default cleartext block doesn't drop them.
String? httpsImage(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('http://')) return 'https://${url.substring(7)}';
  return url;
}

/// EgyBest exposes genres two ways: `genres: [{name}]` (detail/listings) and
/// `genreslist: [string]` (series/anime). Merge whichever is present, de-duped.
List<String> asGenres(dynamic genres, [dynamic genreslist]) {
  final out = <String>[];
  final seen = <String>{};
  void add(String? g) {
    final s = g?.trim();
    if (s != null && s.isNotEmpty && seen.add(s)) out.add(s);
  }

  if (genreslist is List) {
    for (final g in genreslist) {
      add(g?.toString());
    }
  }
  if (genres is List) {
    for (final g in genres) {
      if (g is Map) {
        add(asString(g['name']));
      } else {
        add(g?.toString());
      }
    }
  }
  return out;
}
