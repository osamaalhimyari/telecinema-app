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

    test('appends season/episode segments to an imdb id search', () {
      expect(
        buildOpenSubtitlesSearchUrl(
          imdbId: 'tt0903747',
          season: 1,
          episode: 7,
          langId: 'eng',
        ),
        'https://rest.opensubtitles.org/search/imdbid-903747/season-1/episode-7/sublanguageid-eng',
      );
    });

    test('appends season/episode segments to a query search', () {
      expect(
        buildOpenSubtitlesSearchUrl(
          query: 'Breaking Bad',
          season: 1,
          episode: 7,
          langId: 'ara',
        ),
        'https://rest.opensubtitles.org/search/query-Breaking%20Bad/season-1/episode-7/sublanguageid-ara',
      );
    });

    test('season without episode (whole-season pack)', () {
      expect(
        buildOpenSubtitlesSearchUrl(imdbId: 'tt0903747', season: 1, langId: 'eng'),
        'https://rest.opensubtitles.org/search/imdbid-903747/season-1/sublanguageid-eng',
      );
    });
  });

  group('showTitleFromRelease', () {
    test('cuts at SxxExx', () {
      expect(
        showTitleFromRelease('Breaking.Bad.S01E07.A.No-Rough-Stuff.2160p.NF.WEB-DL.H.265'),
        'Breaking Bad',
      );
    });
    test('cuts at the movie year', () {
      expect(showTitleFromRelease('The.Matrix.1999.1080p.BluRay.x264'), 'The Matrix');
    });
    test('cuts at the resolution when nothing else marks the title', () {
      expect(showTitleFromRelease('Some.Show.1080p.WEB.H264'), 'Some Show');
    });
    test('a plain typed title passes through cleaned', () {
      expect(showTitleFromRelease('Breaking Bad'), 'Breaking Bad');
    });
  });

  group('magnetDisplayName', () {
    test('decodes the dn parameter (+ → space)', () {
      const magnet =
          'magnet:?xt=urn:btih:3657CB8325781402EB40BC572F918E5C455A9200'
          '&dn=Breaking+Bad+S01E07+2160p+NF+WEB-DL+H+265'
          '&tr=udp%3A%2F%2Ftracker.opentrackr.org%3A1337%2Fannounce';
      expect(magnetDisplayName(magnet), 'Breaking Bad S01E07 2160p NF WEB-DL H 265');
    });
    test('null when no dn', () {
      expect(magnetDisplayName('magnet:?xt=urn:btih:ABC123'), isNull);
    });
    test('null for empty/garbage', () {
      expect(magnetDisplayName(''), isNull);
      expect(magnetDisplayName(null), isNull);
    });
    test('feeds subtitleSearchTerms to the right episode', () {
      const magnet = 'magnet:?xt=urn:btih:ABC&dn=Breaking+Bad+S01E07+2160p+H+265';
      final terms = subtitleSearchTerms(magnetDisplayName(magnet)!);
      expect(terms.query, 'Breaking Bad');
      expect(terms.season, 1);
      expect(terms.episode, 7);
    });
  });

  group('subtitleSearchTerms', () {
    test('extracts a clean title plus season/episode from a release name', () {
      final terms = subtitleSearchTerms('Hacks.S01E01.1080p.WEB.H264-GLHF[TGx]');
      expect(terms.query, 'Hacks');
      expect(terms.season, 1);
      expect(terms.episode, 1);
    });
    test('a movie has no season/episode', () {
      final terms = subtitleSearchTerms('Dune.Part.Two.2024.2160p');
      expect(terms.query, 'Dune Part Two');
      expect(terms.season, isNull);
      expect(terms.episode, isNull);
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
