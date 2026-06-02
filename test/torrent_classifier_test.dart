import 'package:flutter_test/flutter_test.dart';
import 'package:watch_aprty_app/features/browse/data/torrent_classifier.dart';

void main() {
  group('parseSeasonEpisode — series', () {
    test('SxxExx episode', () {
      final r = parseSeasonEpisode(
        'The Boys S05E06 Though the Heavens Fall 1080p AMZN WEB-DL',
      );
      expect(r.season, 5);
      expect(r.episode, 6);
    });

    test('dotted name', () {
      final r = parseSeasonEpisode(
        'The.Boys.S05E03.2026.1080p.AMZN.WEBRip.AAC5.1.10bits.x265-Rapta',
      );
      expect(r.season, 5);
      expect(r.episode, 3);
    });

    test('lowercase season-only between dots is a season pack', () {
      final r = parseSeasonEpisode('The Boys.2019.s05.1080p.WEB-DL.H.264.Dual.YG');
      expect(r.season, 5);
      expect(r.episode, isNull);
    });

    test('COMPLETE season pack', () {
      final r = parseSeasonEpisode('The.Boys.S04.COMPLETE.720p.AMZN.WEBRip.x264-GalaxyTV');
      expect(r.season, 4);
      expect(r.episode, isNull);
    });

    test('spelled-out Season N', () {
      final r = parseSeasonEpisode('The Boys - Season 1 - Mp4 x264 AC3 1080p');
      expect(r.season, 1);
      expect(r.episode, isNull);
    });

    test('Season word + S0N token', () {
      final r = parseSeasonEpisode('The Boys - Season 2 S02 - 2020 - 1080p AMZN WEBRip');
      expect(r.season, 2);
      expect(r.episode, isNull);
    });
  });

  group('parseSeasonEpisode — movies have no season/episode', () {
    for (final name in [
      'The Matrix (1999) 1080p BrRip x264 - 1.85GB - YIFY',
      'The.Matrix.1999.2160p.BluRay.HDR.DDP5.1.x265-GalaxyUHD',
      'The.Matrix.1999.1080p.BluRay.DDP5.1.x265.10bit-GalaxyRG265',
      'The Matrix Complete 5 Movie Collection Sci-Fi 1999-2021 Eng 1080',
    ]) {
      test(name, () {
        final r = parseSeasonEpisode(name);
        expect(r.episode, isNull, reason: name);
        expect(r.season, isNull, reason: name);
      });
    }
  });

  group('parseQuality', () {
    test('2160p → 4K', () => expect(parseQuality('...2160p.BluRay...'), '4K'));
    test('1080p', () => expect(parseQuality('...1080p.WEB-DL...'), '1080p'));
    test('720p', () => expect(parseQuality('...720p.WEBRip...'), '720p'));
    test('480p', () => expect(parseQuality('The Boys S05E03 480p x264-mSD'), '480p'));
    test('fallback SD', () => expect(parseQuality('The.Matrix.DVDRIP-ZEKTORM'), 'SD'));
  });

  group('isPackName', () {
    test('trilogy', () => expect(isPackName('The Matrix Trilogy Complete (1999-2003) 720p'), isTrue));
    test('collection', () => expect(isPackName('The Ultimate Matrix Collection 1, 2, 3'), isTrue));
    test('1-4 pack', () => expect(isPackName('The Matrix 1-4 Pack 1999-2021 1080p BluRay'), isTrue));
    test('5 movie collection', () => expect(isPackName('The Matrix Complete 5 Movie Collection'), isTrue));
    test('single film is not a pack', () => expect(isPackName('The Matrix (1999) 1080p BrRip x264 - YIFY'), isFalse));
  });
}
