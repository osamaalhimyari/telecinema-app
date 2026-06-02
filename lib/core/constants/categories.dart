import '../localization/translation_keys.dart';

/// Canonical room category keys. The stable key (not the localized label) is
/// what gets stored on the room (server `category` column) and what the rooms
/// list filters on, so categories stay consistent across languages.
const List<String> kCategories = <String>[
  'movies',
  'series',
  'anime',
  'sports',
  'music',
  'gaming',
  'news',
  'other',
];

/// Maps a category key to its [TranslationKeys] label. Unknown / legacy values
/// fall back to themselves, so `context.tr` renders the raw value rather than
/// throwing or showing a blank.
String categoryLabelKey(String category) {
  switch (category) {
    case 'movies':
      return TranslationKeys.categoryMovies;
    case 'series':
      return TranslationKeys.categorySeries;
    case 'anime':
      return TranslationKeys.categoryAnime;
    case 'sports':
      return TranslationKeys.categorySports;
    case 'music':
      return TranslationKeys.categoryMusic;
    case 'gaming':
      return TranslationKeys.categoryGaming;
    case 'news':
      return TranslationKeys.categoryNews;
    case 'other':
      return TranslationKeys.categoryOther;
    default:
      return category;
  }
}
