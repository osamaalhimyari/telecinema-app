/// Bilingual TMDB genre table, used to unify genre chips in the merged Browse
/// grid. Cinemeta ships English genre names, EgyBest ships Arabic ones — both
/// come from TMDB, so this maps either spelling to one canonical entry and
/// renders it in the app's current language. Unknown genres pass through
/// unchanged.
class GenreMap {
  GenreMap._();

  /// `[english, arabic]` for the standard TMDB movie + TV genres.
  static const List<List<String>> _table = [
    ['Action', 'حركة'],
    ['Adventure', 'مغامرة'],
    ['Animation', 'رسوم متحركة'],
    ['Comedy', 'كوميديا'],
    ['Crime', 'جريمة'],
    ['Documentary', 'وثائقي'],
    ['Drama', 'دراما'],
    ['Family', 'عائلي'],
    ['Fantasy', 'فانتازيا'],
    ['History', 'تاريخ'],
    ['Horror', 'رعب'],
    ['Music', 'موسيقى'],
    ['Mystery', 'غموض'],
    ['Romance', 'رومانسية'],
    ['Science Fiction', 'خيال علمي'],
    ['TV Movie', 'فيلم تلفزيوني'],
    ['Thriller', 'إثارة'],
    ['War', 'حرب'],
    ['Western', 'غربي'],
    ['Action & Adventure', 'حركة ومغامرة'],
    ['Kids', 'أطفال'],
    ['News', 'أخبار'],
    ['Reality', 'واقع'],
    ['Sci-Fi & Fantasy', 'خيال علمي وفانتازيا'],
    ['Soap', 'أوبرا صابونية'],
    ['Talk', 'برامج حوارية'],
    ['War & Politics', 'حرب وسياسة'],
  ];

  /// Alternate spellings → the canonical Arabic name in [_table].
  static const Map<String, String> _arAliases = {
    'رومنسية': 'رومانسية',
    'اكشن': 'حركة',
    'مغامرات': 'مغامرة',
    'دراما إذاعية': 'أوبرا صابونية',
  };

  static final Map<String, List<String>> _byEn = {
    for (final e in _table) e[0].toLowerCase(): e,
  };
  static final Map<String, List<String>> _byAr = {
    for (final e in _table) e[1]: e,
  };

  /// Canonical name of [raw] (English or Arabic) in [lang] (`en`/`ar`); returns
  /// [raw] unchanged when the genre isn't in the table.
  static String localize(String raw, String lang) {
    final key = raw.trim();
    var entry = _byEn[key.toLowerCase()] ?? _byAr[key];
    if (entry == null) {
      final canonAr = _arAliases[key];
      if (canonAr != null) entry = _byAr[canonAr];
    }
    if (entry == null) return key;
    return lang == 'ar' ? entry[1] : entry[0];
  }

  /// Localizes a list and de-duplicates (so `Action` + `حركة` collapse to one).
  static List<String> localizeAll(Iterable<String> raw, String lang) {
    final seen = <String>{};
    final out = <String>[];
    for (final g in raw) {
      final l = localize(g, lang);
      if (l.isNotEmpty && seen.add(l)) out.add(l);
    }
    return out;
  }
}
