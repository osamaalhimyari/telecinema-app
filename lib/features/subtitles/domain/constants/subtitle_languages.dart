/// One selectable subtitle language: the OpenSubtitles ISO 639-2 [id] (sent in
/// the `sublanguageid-…` path) and a human-readable [label] for the dropdown.
typedef SubtitleLanguage = ({String id, String label});

/// Curated set of common OpenSubtitles languages. Codes are the ISO 639-2/B
/// values the legacy REST API expects (e.g. `fre`, `ger`, `rum`), not the
/// 639-1 two-letter ones. The dropdown shows [SubtitleLanguage.label].
const List<SubtitleLanguage> kSubtitleLanguages = [
  (id: 'eng', label: 'English'),
  (id: 'ara', label: 'Arabic'),
  (id: 'spa', label: 'Spanish'),
  (id: 'fre', label: 'French'),
  (id: 'ger', label: 'German'),
  (id: 'ita', label: 'Italian'),
  (id: 'por', label: 'Portuguese'),
  (id: 'pob', label: 'Portuguese (BR)'),
  (id: 'rus', label: 'Russian'),
  (id: 'hin', label: 'Hindi'),
  (id: 'tur', label: 'Turkish'),
  (id: 'dut', label: 'Dutch'),
  (id: 'pol', label: 'Polish'),
  (id: 'swe', label: 'Swedish'),
  (id: 'jpn', label: 'Japanese'),
  (id: 'kor', label: 'Korean'),
  (id: 'chi', label: 'Chinese'),
  (id: 'per', label: 'Persian'),
  (id: 'heb', label: 'Hebrew'),
  (id: 'ind', label: 'Indonesian'),
  (id: 'rum', label: 'Romanian'),
  (id: 'gre', label: 'Greek'),
  (id: 'ukr', label: 'Ukrainian'),
  (id: 'vie', label: 'Vietnamese'),
  (id: 'tha', label: 'Thai'),
  (id: 'cze', label: 'Czech'),
  (id: 'dan', label: 'Danish'),
  (id: 'fin', label: 'Finnish'),
  (id: 'nor', label: 'Norwegian'),
  (id: 'hun', label: 'Hungarian'),
];

/// Default language id for the app's current [languageCode] — Arabic maps to
/// `ara`, everything else falls back to English.
String defaultSubtitleLanguageId(String languageCode) =>
    languageCode == 'ar' ? 'ara' : 'eng';
