import 'package:equatable/equatable.dart';

/// The room's authoritative playback state, as relayed by the server's `sync`
/// (and `rate_changed` / `source_changed`) events.
class PlaybackSync extends Equatable {
  const PlaybackSync({
    required this.isPlaying,
    required this.currentTime,
    required this.playbackRate,
    required this.serverTime,
  });

  final bool isPlaying;

  /// Seconds into the video at [serverTime].
  final double currentTime;
  final double playbackRate;

  /// `Date.now()` (ms) on the server when this state was emitted — used to
  /// extrapolate the true position accounting for network + processing delay.
  final int serverTime;

  /// Position "now", advanced past [currentTime] by however long ago the
  /// server sent this while playing.
  double effectiveTime() {
    if (!isPlaying) return currentTime;
    final elapsedMs = DateTime.now().millisecondsSinceEpoch - serverTime;
    return currentTime + (elapsedMs / 1000.0) * (playbackRate == 0 ? 1 : playbackRate);
  }

  factory PlaybackSync.fromJson(Map<String, dynamic> json) => PlaybackSync(
    isPlaying: json['isPlaying'] == true,
    currentTime: _d(json['currentTime']),
    playbackRate: json['playbackRate'] == null ? 1.0 : _d(json['playbackRate']),
    serverTime: json['serverTime'] is num
        ? (json['serverTime'] as num).toInt()
        : DateTime.now().millisecondsSinceEpoch,
  );

  static double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0.0;

  @override
  List<Object?> get props => [isPlaying, currentTime, playbackRate, serverTime];
}
