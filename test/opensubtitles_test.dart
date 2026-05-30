import 'package:flutter_test/flutter_test.dart';
import 'package:watch_aprty_app/features/subtitles/data/datasources/opensubtitles_datasource.dart';

void main() {
  group('imdbDigits', () {
    test('strips tt prefix', () => expect(imdbDigits('tt1190634'), '1190634'));
    test('strips leading zeros', () => expect(imdbDigits('tt0133093'), '133093'));
    test('already numeric', () => expect(imdbDigits('1190634'), '1190634'));
    test('no digits → empty', () => expect(imdbDigits('tt'), ''));
  });

  group('buildOpenSubtitlesSearchUrl', () {
    test('imdb id is preferred', () {
      expect(
        buildOpenSubtitlesSearchUrl(imdbId: 'tt1190634', query: 'ignored', langId: 'ara'),
        'https://rest.opensubtitles.org/search/imdbid-1190634/sublanguageid-ara',
      );
    });

    test('falls back to query when no imdb id', () {
      expect(
        buildOpenSubtitlesSearchUrl(imdbId: null, query: 'The Matrix', langId: 'eng'),
        'https://rest.opensubtitles.org/search/query-The%20Matrix/sublanguageid-eng',
      );
    });

    test('falls back to query when imdb id has no digits', () {
      expect(
        buildOpenSubtitlesSearchUrl(imdbId: 'tt', query: 'Dune', langId: 'eng'),
        'https://rest.opensubtitles.org/search/query-Dune/sublanguageid-eng',
      );
    });

    test('null when neither key is usable', () {
      expect(buildOpenSubtitlesSearchUrl(imdbId: null, query: '  ', langId: 'eng'), isNull);
    });
  });

  group('parseSubtitleResults', () {
    final sample = [
      {
        'IDSubtitleFile': '111',
        'SubFileName': 'The.Boys.S05E06.srt',
        'SubLanguageID': 'ara',
        'LanguageName': 'Arabic',
        'SubFormat': 'srt',
        'SubDownloadLink': 'https://dl.opensubtitles.org/x/111.gz',
        'MovieReleaseName': 'The.Boys.S05E06.1080p',
        'SubDownloadsCnt': '500',
        'SubRating': '8.5',
      },
      {
        'IDSubtitleFile': '222',
        'SubFileName': 'b.srt',
        'SubLanguageID': 'ara',
        'SubFormat': 'srt',
        'SubDownloadLink': 'https://dl.opensubtitles.org/x/222.gz',
        'SubDownloadsCnt': '900',
      },
      // Duplicate id of the first — dropped.
      {
        'IDSubtitleFile': '111',
        'SubFileName': 'dupe.srt',
        'SubDownloadLink': 'https://dl.opensubtitles.org/x/111b.gz',
        'SubDownloadsCnt': '10',
      },
      // No download link — dropped.
      {'IDSubtitleFile': '333', 'SubFileName': 'c.srt'},
    ];

    test('parses, de-dupes, and sorts by downloads desc', () {
      final results = parseSubtitleResults(sample);
      expect(results.length, 2);
      expect(results.first.id, '222'); // 900 downloads first
      expect(results[1].id, '111');
      expect(results[1].releaseName, 'The.Boys.S05E06.1080p');
      expect(results[1].rating, 8.5);
      expect(results.first.title, 'b.srt'); // no release name → file name
    });

    test('non-list input → empty', () {
      expect(parseSubtitleResults({'error': 'nope'}), isEmpty);
    });
  });
}
