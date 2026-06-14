import 'package:equatable/equatable.dart';

/// A direct, downloadable media link produced by the resolver from a
/// [CinemaServer]. One server can resolve to several of these (e.g. multiple
/// qualities), which is when the UI shows a quality picker before creating the
/// room.
class CinemaStream extends Equatable {
  const CinemaStream({
    required this.url,
    required this.qualityLabel,
    this.isHls = false,
    this.sizeBytes,
  });

  /// The direct `.mp4` / `.m3u8` url pasted into the Create Room download field.
  final String url;

  /// e.g. `1080p`, `720p`, or `Auto` when the host doesn't expose a height.
  final String qualityLabel;

  /// HLS playlist (`.m3u8`) rather than a single progressive file.
  final bool isHls;

  /// Approximate size in bytes when the host reports it, for the picker subtitle.
  final int? sizeBytes;

  String get humanSize {
    final b = sizeBytes;
    if (b == null || b <= 0) return '';
    const gb = 1024 * 1024 * 1024, mb = 1024 * 1024;
    if (b >= gb) return '${(b / gb).toStringAsFixed(2)} GB';
    return '${(b / mb).toStringAsFixed(0)} MB';
  }

  @override
  List<Object?> get props => [url, qualityLabel, isHls];
}
