// Smoke tests for the watch-party domain layer. Widget tests that pump the
// whole app are intentionally avoided here because the app boots HydratedBloc
// storage and GetIt dependencies in `main()`.

import 'package:flutter_test/flutter_test.dart';
import 'package:watch_aprty_app/features/rooms/data/models/room_model.dart';
import 'package:watch_aprty_app/features/rooms/domain/entities/room_type.dart';
import 'package:watch_aprty_app/features/watch/domain/entities/playback_sync.dart';

void main() {
  group('RoomModel.fromJson', () {
    test('parses the API room shape', () {
      final model = RoomModel.fromJson({
        'id': 1,
        'name': 'Nature',
        'slug': 'nature',
        'roomType': 'upload',
        'hasPassword': false,
        'isUserCreated': false,
        'viewCount': 5,
        'viewerCount': 2,
        'reactionsList': ['👍', '🔥'],
        'videoFilename': 'nature.mp4',
      });
      final room = model.toEntity();

      expect(room.slug, 'nature');
      expect(room.roomType, RoomType.upload);
      expect(room.viewerCount, 2);
      expect(room.reactions, ['👍', '🔥']);
      expect(room.videoUrl, contains('/video/nature.mp4'));
    });

    test('falls back to the default reaction palette for an external room', () {
      final room = RoomModel.fromJson({'id': 2, 'slug': 'x', 'roomType': 'external'}).toEntity();
      expect(room.reactions, isNotEmpty);
      expect(room.isExternal, isTrue);
      expect(room.videoUrl, isNull);
    });
  });

  group('PlaybackSync.effectiveTime', () {
    test('does not advance while paused', () {
      const sync = PlaybackSync(
        isPlaying: false,
        currentTime: 42,
        playbackRate: 1,
        serverTime: 0,
      );
      expect(sync.effectiveTime(), 42);
    });

    test('extrapolates forward while playing', () {
      final sync = PlaybackSync(
        isPlaying: true,
        currentTime: 10,
        playbackRate: 1,
        serverTime: DateTime.now().millisecondsSinceEpoch - 2000,
      );
      expect(sync.effectiveTime(), greaterThanOrEqualTo(11.5));
    });
  });
}
