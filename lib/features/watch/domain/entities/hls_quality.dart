import 'package:equatable/equatable.dart';

/// One selectable rung of the server's adaptive-HLS ladder, parsed from the
/// room's `master.m3u8` at runtime. Deriving the menu from the master playlist
/// (instead of hardcoding 720p/480p/240p) keeps the client correct no matter how
/// many renditions the server is configured to produce (see HLS_RENDITIONS).
class HlsQuality extends Equatable {
  const HlsQuality({required this.label, required this.url, required this.height});

  /// Human label shown in the menu, e.g. `480p`.
  final String label;

  /// Absolute URL of this variant's playlist (a pinned quality).
  final String url;

  /// Vertical resolution in pixels; 0 when the master didn't advertise one.
  /// Used only to order the menu highest-first.
  final int height;

  @override
  List<Object?> get props => [label, url, height];
}
