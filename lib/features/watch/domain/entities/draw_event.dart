import 'dart:ui' show Offset;

import 'package:equatable/equatable.dart';

/// One segment of an ephemeral drawing stroke relayed over the room socket.
///
/// Points are normalized to the unit square (0..1) against the sender's player
/// box, so they map onto every viewer's player regardless of its size. A stroke
/// is identified by [strokeId]; successive segments with the same id append to
/// the same line, and [done] marks the final segment. [id] is the sender's
/// socket id (`'me'` for the local echo, mirroring [ReactionEvent]).
class DrawEvent extends Equatable {
  const DrawEvent({
    required this.id,
    required this.name,
    required this.strokeId,
    required this.color,
    required this.points,
    required this.done,
  });

  final String id;
  final String name;
  final String strokeId;

  /// `#RRGGBB` pen color chosen by the sender.
  final String color;

  /// Normalized (0..1) points added by this segment.
  final List<Offset> points;

  /// True for the segment that ends the stroke.
  final bool done;

  /// Stable key that keeps one user's stroke distinct from another's even if
  /// their local stroke ids happen to collide.
  String get key => '$id:$strokeId';

  factory DrawEvent.fromJson(Map<String, dynamic> json) {
    final raw = json['points'];
    final points = <Offset>[];
    if (raw is List) {
      for (final p in raw) {
        if (p is List && p.length >= 2) {
          final x = (p[0] as num?)?.toDouble();
          final y = (p[1] as num?)?.toDouble();
          if (x != null && y != null) points.add(Offset(x, y));
        }
      }
    }
    return DrawEvent(
      id: json['id']?.toString() ?? '',
      name: (json['name'] ?? '').toString(),
      strokeId: json['strokeId']?.toString() ?? '',
      color: (json['color'] ?? '#ffffff').toString(),
      points: points,
      done: json['done'] == true,
    );
  }

  @override
  List<Object?> get props => [id, name, strokeId, color, points, done];
}
